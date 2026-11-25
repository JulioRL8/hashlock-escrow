// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {HashlockEscrow} from "../src/HashlockEscrow.sol";
import {TestBase} from "./TestBase.sol";

contract HashlockEscrowTest is TestBase {
    address private constant SENDER = address(0xA11CE);
    address payable private constant BENEFICIARY = payable(address(0xB0B));
    bytes32 private constant SECRET = bytes32(uint256(42));
    bytes32 private constant DIGEST = keccak256(abi.encode(SECRET));
    HashlockEscrow private escrow;

    function setUp() public {
        vm.deal(SENDER, 2 ether);
        vm.deal(address(this), 2 ether);
        vm.prank(SENDER);
        escrow = new HashlockEscrow{value: 1 ether}(BENEFICIARY, DIGEST, 1 days);
    }

    function testRejectsZeroBeneficiary() public {
        vm.expectRevert(HashlockEscrow.InvalidConfiguration.selector);
        new HashlockEscrow{value: 1}(payable(address(0)), DIGEST, 1);
    }

    function testRejectsEmptyDigest() public {
        vm.expectRevert(HashlockEscrow.InvalidConfiguration.selector);
        new HashlockEscrow{value: 1}(BENEFICIARY, bytes32(0), 1);
    }

    function testRejectsZeroDuration() public {
        vm.expectRevert(HashlockEscrow.InvalidConfiguration.selector);
        new HashlockEscrow{value: 1}(BENEFICIARY, DIGEST, 0);
    }

    function testRejectsEmptyEscrow() public {
        vm.expectRevert(HashlockEscrow.EmptyEscrow.selector);
        new HashlockEscrow(BENEFICIARY, DIGEST, 1);
    }

    function testClaimAlwaysPaysBeneficiary() public {
        vm.warp(escrow.expiresAt() - 1);
        vm.expectRevert(HashlockEscrow.InvalidSecret.selector);
        escrow.claim(bytes32(0));
        escrow.claim(SECRET);
        assertTrue(escrow.settled());
        assertEq(BENEFICIARY.balance, 1 ether);
        assertEq(address(escrow).balance, 0);

        vm.expectRevert(HashlockEscrow.AlreadySettled.selector);
        escrow.claim(SECRET);
        vm.expectRevert(HashlockEscrow.AlreadySettled.selector);
        escrow.refund();
    }

    function testRefundAtExpiryPaysSender() public {
        vm.expectRevert(HashlockEscrow.RefundTooEarly.selector);
        escrow.refund();

        vm.warp(escrow.expiresAt());
        vm.expectRevert(HashlockEscrow.EscrowExpired.selector);
        escrow.claim(SECRET);
        escrow.refund();
        assertTrue(escrow.settled());
        assertEq(SENDER.balance, 2 ether);
    }

    function testRevertedPayoutPreservesDeposit() public {
        HashlockEscrow rejected = new HashlockEscrow{value: 1}(payable(address(this)), DIGEST, 1);
        vm.expectRevert(HashlockEscrow.TransferFailed.selector);
        rejected.claim(SECRET);
        assertTrue(!rejected.settled());
        assertEq(address(rejected).balance, 1);
    }

    function testFuzzClaim(bytes32 secret, uint96 amount) public {
        vm.assume(amount != 0);
        vm.deal(address(this), amount);
        HashlockEscrow funded = new HashlockEscrow{value: amount}(BENEFICIARY, keccak256(abi.encode(secret)), 1 days);
        funded.claim(secret);
        assertEq(BENEFICIARY.balance, amount);
    }
}
