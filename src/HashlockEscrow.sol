// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

contract HashlockEscrow {
    error InvalidConfiguration();
    error EmptyEscrow();
    error AlreadySettled();
    error EscrowExpired();
    error RefundTooEarly();
    error InvalidSecret();
    error TransferFailed();

    address payable public immutable sender;
    address payable public immutable beneficiary;
    bytes32 public immutable commitment;
    uint256 public immutable expiresAt;
    uint256 public immutable deposit;
    bool public settled;

    event Claimed(bytes32 secret);
    event Refunded();

    constructor(address payable recipient, bytes32 digest, uint64 duration) payable {
        if (recipient == address(0)) revert InvalidConfiguration();
        if (digest == bytes32(0)) revert InvalidConfiguration();
        if (duration == 0) revert InvalidConfiguration();
        if (msg.value == 0) revert EmptyEscrow();

        sender = payable(msg.sender);
        beneficiary = recipient;
        commitment = digest;
        expiresAt = block.timestamp + duration;
        deposit = msg.value;
    }

    function claim(bytes32 secret) external {
        if (settled) revert AlreadySettled();
        if (block.timestamp >= expiresAt) revert EscrowExpired();
        if (keccak256(abi.encode(secret)) != commitment) revert InvalidSecret();

        emit Claimed(secret);
        _settle(beneficiary);
    }

    function refund() external {
        if (settled) revert AlreadySettled();
        if (block.timestamp < expiresAt) revert RefundTooEarly();

        emit Refunded();
        _settle(sender);
    }

    function _settle(address payable recipient) private {
        settled = true;
        (bool sent,) = recipient.call{value: deposit}("");
        if (!sent) revert TransferFailed();
    }
}
