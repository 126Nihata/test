
 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

contract OriginPermitSwallowTest is Test {
    address internal user = address(0x1337);

    function setUp() public {
        vm.deal(user, 100 ether);
    }

    function testPermitErrorSwallowingAndAllowanceBypass() public {
        uint256 deadline = block.timestamp == 0
            ? 0
            : block.timestamp - 1;

        uint8 v = 27;
        bytes32 r = bytes32(0);
        bytes32 s = bytes32(0);
        uint256 amount = 1000e18;

        bool executionContinued = false;

        try this.simulateProtocolEntryWithPermit(
            user,
            amount,
            deadline,
            v,
            r,
            s
        ) {
            executionContinued = true;
        } catch {
            executionContinued = false;
        }

        assertTrue(
            executionContinued,
            "Expected execution to continue after permit error was caught"
        );
    }

    function simulateProtocolEntryWithPermit(
        address owner,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        try this.externalPermitCall(
            owner,
            amount,
            deadline,
            v,
            r,
            s
        ) {
            // Permit call succeeded.
        } catch {
            // Permit failure is intentionally ignored.
        }

        this.simulateDownstreamTransfer(owner, amount);
    }

    function externalPermitCall(
        address,
        uint256,
        uint256 deadline,
        uint8,
        bytes32,
        bytes32
    ) external view {
        require(
            deadline >= block.timestamp,
            "Permit expired or invalid"
        );
    }

    function simulateDownstreamTransfer(
        address,
        uint256
    ) external pure {
        // Simulate a downstream transfer.
    }
}
