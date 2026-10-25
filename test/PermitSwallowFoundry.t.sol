
 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockPermitToken is ERC20Permit {
    constructor()
        ERC20("Mock Permit Token", "MPT")
        ERC20Permit("Mock Permit Token")
    {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract PermitSwallowTarget {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    mapping(address => uint256) public deposits;

    constructor(address tokenAddress) {
        token = IERC20(tokenAddress);
    }

    function depositWithPermit(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        try MockPermitToken(address(token)).permit(
            msg.sender,
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        ) {
        } catch {
            // The permit failure is intentionally ignored.
        }

        token.safeTransferFrom(msg.sender, address(this), amount);
        deposits[msg.sender] += amount;
    }
}

contract PermitSwallowFoundryTest is Test {
    MockPermitToken token;
    PermitSwallowTarget target;

    uint256 private userPrivateKey = 0xA11CE;
    address private user;

    uint256 private constant INITIAL_BALANCE = 100 ether;
    uint256 private constant DEPOSIT_AMOUNT = 40 ether;

    function setUp() public {
        vm.warp(1000);

        user = vm.addr(userPrivateKey);
        token = new MockPermitToken();
        target = new PermitSwallowTarget(address(token));

        token.mint(user, INITIAL_BALANCE);

        vm.prank(user);
        token.approve(address(target), INITIAL_BALANCE);
    }

    function testPoC_ExpiredPermitAndExistingAllowance() public {
        uint256 expiredDeadline = block.timestamp - 1;

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            userPrivateKey,
            keccak256("invalid-test-signature")
        );

        assertEq(
            token.allowance(user, address(target)),
            INITIAL_BALANCE,
            "Expected existing allowance"
        );

        vm.prank(user);
        target.depositWithPermit(
            DEPOSIT_AMOUNT,
            expiredDeadline,
            v,
            r,
            s
        );

        assertEq(
            token.balanceOf(user),
            INITIAL_BALANCE - DEPOSIT_AMOUNT,
            "Incorrect user balance"
        );

        assertEq(
            token.balanceOf(address(target)),
            DEPOSIT_AMOUNT,
            "Incorrect target balance"
        );

        assertEq(
            target.deposits(user),
            DEPOSIT_AMOUNT,
            "Incorrect deposit accounting"
        );

        assertEq(
            token.allowance(user, address(target)),
            INITIAL_BALANCE - DEPOSIT_AMOUNT,
            "Incorrect remaining allowance"
        );
    }

    function testPoC_NoAllowanceCausesRevert() public {
        vm.prank(user);
        token.approve(address(target), 0);

        vm.prank(user);
        vm.expectRevert();
        target.depositWithPermit(
            DEPOSIT_AMOUNT,
            block.timestamp - 1,
            27,
            bytes32(0),
            bytes32(0)
        );

        assertEq(
            token.balanceOf(address(target)),
            0,
            "Unexpected token transfer"
        );

        assertEq(
            target.deposits(user),
            0,
            "Unexpected deposit accounting"
        );
    }
}
