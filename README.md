# MultiSigWallet Smart Contract
A robust multi-signature wallet written in Solidity, enabling secure and decentralized transaction management by requiring multiple owner approvals before execution.

### License
SPDX-License-Identifier: GPL-3.0

## Features
1. Multi-signature support – Require approval from a predefined number of owners before transactions are executed.
2. Transaction lifecycle management – Submit, confirm, revoke, and execute transactions.
3. Owner verification – Only registered wallet owners can submit or approve transactions.
4. Call support – Supports callData for calling functions on other contracts.
5. ETH handling – Accepts and handles Ether transfers via receive and fallback functions.

### How It Works
Deployment – Specify an array of owners and the number of required approvals.

Submit Transaction – An owner submits a transaction (recipient, value, and optional data).

Confirm Transaction – Other owners confirm the transaction.

Execute Transaction – Once the required confirmations are collected, any owner can execute it.

### Events Emitted
SubmitTransaction
ConfirmTransaction
RevokeConfirmation
ExecuteTransaction



