
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

contract MockStakeToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount)
        external
        returns (bool)
    {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    // Simulate a failed permit call.
    function permit(
        address,
        address,
        uint256,
        uint256,
        uint8,
        bytes32,
        bytes32
    ) external pure {
        revert("permit failed");
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        uint256 permitted = allowance[from][msg.sender];
        require(permitted >= amount, "insufficient allowance");
        require(balanceOf[from] >= amount, "insufficient balance");

        if (permitted != type(uint256).max) {
            allowance[from][msg.sender] = permitted - amount;
        }

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        return true;
    }
}

contract UniStakerMock {
    MockStakeToken public immutable token;
    mapping(address => uint256) public staked;

    constructor(MockStakeToken _token) {
        token = _token;
    }

    function stakeWithPermit(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        try token.permit(
            msg.sender,
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        ) {
            // Permit succeeded.
        } catch {
            // Deliberately continue for this simulation.
        }

        require(
            token.transferFrom(msg.sender, address(this), amount),
            "transfer failed"
        );

        staked[msg.sender] += amount;
    }
}

contract UniStakerPermitSwallowingTest is Test {
    MockStakeToken token;
    UniStakerMock staker;

    address alice = address(0xA11CE);

    function setUp() public {
        token = new MockStakeToken();
        staker = new UniStakerMock(token);

        token.mint(alice, 100 ether);

        vm.prank(alice);
        token.approve(address(staker), 100 ether);
    }

    function testUniStakerPermitSwallowingBypass() public {
        uint256 amount = 40 ether;

        // Permit reverts, but the existing allowance is sufficient.
        vm.prank(alice);
        staker.stakeWithPermit(
            amount,
            block.timestamp + 1 hours,
            27,
            bytes32(0),
            bytes32(0)
        );

        assertEq(token.balanceOf(alice), 60 ether);
        assertEq(token.balanceOf(address(staker)), 40 ether);
        assertEq(staker.staked(alice), 40 ether);
        assertEq(token.allowance(alice, address(staker)), 60 ether);
    }

    function testInsufficientAllowanceRevertsWithoutUnderflow()
        public
    {
        vm.prank(alice);
        token.approve(address(staker), 10 ether);

        vm.prank(alice);
        vm.expectRevert(
            bytes("insufficient allowance")
        );

        staker.stakeWithPermit(
            40 ether,
            block.timestamp + 1 hours,
            27,
            bytes32(0),
            bytes32(0)
        );

        // The reverted transaction changes no balances.
        assertEq(token.balanceOf(alice), 100 ether);
        assertEq(staker.staked(alice), 0);
    }
}
