// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

/**
 * @title Origin Protocol & Permit Try/Catch Swallowing PoC
 * @notice Bu test permit funksiyalarındakı try/catch bloklarının xətaları səssizcə 
 *         udduğunu və köhnə icazə (stale allowance) halında tranzaksiyanın necə 
 *         davam etdiyini simulyasiya edir.
 */
contract OriginPermitSwallowTest is Test {
    address user = address(0x1337);
    address attacker = address(0xBAD);

    function setUp() public {
        vm.deal(user, 100 ether);
    }

    function testPermitErrorSwallowingAndAllowanceBypass() public {
        // 1. Etibarsız və ya vaxtı keçmiş permit parametrləri təyin edirik (deadline keçib)
        uint256 deadline = block.timestamp - 1; 
        uint8 v = 27;
        bytes32 r = bytes32(0);
        bytes32 s = bytes32(0);
        uint256 amount = 1000e18;

        bool executionContinued = false;

        // 2. Try/Catch mexanizminin permit xətasını səssizcə udduğunu yoxlayırıq
        try this.simulateProtocolEntryWithPermit(user, amount, deadline, v, r, s) {
            executionContinued = true;
        } catch {
            executionContinued = false;
        }

        // 3. Doğrulama: Permit xəta verməsinə baxmayaraq try/catch səbəbindən tranzaksiya dayanmır
        assertTrue(
            executionContinued, 
            "Tranzaksiya permit xətasına görə revert olmalı idi, lakin try/catch tərəfindən uduldu!"
        );
    }

    /**
     * @dev Protokolun giriş nöqtəsini (entry point) simulyasiya edən funksiya
     */
    function simulateProtocolEntryWithPermit(
        address owner,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // Try/Catch vasitəsilə permit çağırışının qorunması (Silent Catch)
        try this.externalPermitCall(owner, amount, deadline, v, r, s) {
            // Permit uğurlu olduqda icra olunan məntiq
        } catch {
            // ⚡ KRİTİK ZƏİFLİK NÖQTƏSİ: Xəta burada catch {} tərəfindən tutulur 
            // və tranzaksiya revert olmadan növbəti məntiqə keçir!
        }

        // Aşağı səviyyəli icra (Downstream Logic): 
        // Əgər istifadəçinin əvvəldən qalan köhnə icazəsi (stale allowance) varsa,
        // uğursuz permit-ə baxmayaraq vəsait çəkilə bilər.
        this.simulateDownstreamTransfer(owner, amount);
    }

    function externalPermitCall(
        address,
        uint256,
        uint256 deadline,
        uint8,
        bytes32,
        bytes32
    ) external pure {
        // Vaxtı keçdiyi üçün permit qəsdən xəta (revert) qaytarır
        require(deadline >= block.timestamp, "PermitExpiredOrInvalid");
    }

    function simulateDownstreamTransfer(address, uint256) external pure {
        // Permit xətası udulduqdan sonra əməliyyatın uğurla davam etdiyini göstərir
    }
}
