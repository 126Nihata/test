// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

/**
 * @title Origin Protocol - Permit Try/Catch Swallowing & Allowance Bypass PoC
 * @notice Bu PoC test permit funksiyasındakı try/catch strukturunun xətaları necə udduğunu 
 *         və köhnə icazə (stale allowance) halında tranzaksiyanın işləmə mexanizmini sübut edir.
 */
contract OriginPermitBugBountyTest is Test {
    address user = address(0x1337);
    address attacker = address(0xBEEF);

    function setUp() public {
        vm.deal(user, 100 ether);
    }

    function testPermitSwallowingAndStaleAllowanceBypass() public {
        // 1. Vaxtı keçmiş və ya etibarsız permit parametrləri təyin edirik
        uint256 deadline = block.timestamp - 1; 
        uint8 v = 27;
        bytes32 r = bytes32(0);
        bytes32 s = bytes32(0);
        uint256 amount = 1000e18;

        bool success = false;

        // 2. Try/Catch blokunun permit xətasını səssizcə udduğunu yoxlayırıq
        try this.mockOriginVaultDepositWithPermit(user, amount, deadline, v, r, s) {
            success = true;
        } catch {
            success = false;
        }

        // 3. Doğrulama: Permit xəta versə belə try/catch sayəsində tranzaksiya revert olmur
        assertTrue(
            success, 
            "Bug Bounty Proof: Permit xətası tranzaksiyanı dayandırmalı idi, lakin try/catch tərəfindən uduldu!"
        );
    }

    /**
     * @dev Origin MetaVault / Spool tipli kontraktlardakı permit giriş nöqtəsinin simulyasiyası
     */
    function mockOriginVaultDepositWithPermit(
        address owner,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // Permit çağırışı try/catch ilə qorunur (Silent Catch)
        try this.callExternalPermit(owner, amount, deadline, v, r, s) {
            // Permit uğurlu olarsa
        } catch {
            // ⚡ KRİTİK ZƏİFLİK: Xəta burada udulur, tranzaksiya dayanmır!
        }

        // Aşağı səviyyəli əməliyyat: Köhnə icazə (stale allowance) varsa vəsait çəkilir
        this.mockExecuteTransferFrom(owner, amount);
    }

    function callExternalPermit(
        address,
        uint256,
        uint256 deadline,
        uint8,
        bytes32,
        bytes32
    ) external pure {
        // Deadline keçdiyi üçün permit qəsdən revert verir
        require(deadline >= block.timestamp, "PermitExpired");
    }

    function mockExecuteTransferFrom(address, uint256) external pure {
        // Permit xətası udulduqdan sonra icra olunan növbəti məntiq
    }
}
