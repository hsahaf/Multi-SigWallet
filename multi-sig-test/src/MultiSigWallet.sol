// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

contract MultiSigWallet {

    // ========== Transaction Struct ==========
    struct Transaction {
        address recipientAddress;
        uint256 value;
        bytes callData;  // two scenarios: 1. Direct transfer, no callData needed,
                                        // 2. external call to a different contract 
                                        // abi encoding of the external call, 
        bool beenExecuted;
        uint numSignatures;
    }

    Transaction[] public allTransactions; // just the list of all transactions

    // ========== Ownership ==========
    uint public required; // number of required signatures for a transaction to execute
    address[] public owners; // list of the addresses of owners
    mapping(address => bool) public OwneriD; // allows you to quickly check whether an address is one of an owner
    mapping(uint => mapping(address => bool)) public isConfirmed;
    // based on the transaction number, you check whether the address has provided a confirmation

    // ========== Events ==========
    event SubmitTx(address indexed owner, uint indexed txId, address indexed recipient, uint value, bytes data);
    event ConfirmTx(address indexed owner, uint indexed txId);
    event RevokeConfirmation(address indexed owner, uint indexed txId);
    event ExecuteTx(address indexed owner, uint indexed txId);

    // ========== Modifiers ==========
    modifier onlyOwner() {
        require(OwneriD[msg.sender], "Only owner.");
        _;
    }

    modifier notExecuted(uint _txId) {
    require(!allTransactions[_txId].beenExecuted, "Already executed");
    _;
    }

    modifier txExists(uint _txId) {
    require(_txId < allTransactions.length, "No such transaction.");
    _;
    }

    modifier notConfirmed(uint _txId) {
    require(!isConfirmed[_txId][msg.sender], "Already confirmed");
    _;
    }

    // ========== Constructor ==========
    constructor(address[] memory _owners, uint _required) {
        require(_owners.length >= _required, "Invalid # of confirmations");
        require(_required > 0, "Minimum one required.");
        uint256 maxOwners = 5;

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!OwneriD[owner], "Owner not unique");
            require(i< maxOwners, "Too many owners");

            OwneriD[owner] = true;
            owners.push(owner);
        }

        required = _required;
    }

    // ========== Functions ==========
    function submitTransaction(address _recipientAddress, uint _value, bytes memory _callData) public onlyOwner {
    uint txId = allTransactions.length;
    allTransactions.push(Transaction({
        recipientAddress: _recipientAddress,
        value: _value,
        callData: _callData,
        beenExecuted: false,
        numSignatures: 0
    }));

    emit SubmitTx(msg.sender, txId, _recipientAddress, _value, _callData);
    }

    function confirmTransaction(uint _txId) public onlyOwner txExists(_txId) notExecuted(_txId) notConfirmed(_txId) {

    isConfirmed[_txId][msg.sender] = true;
    allTransactions[_txId].numSignatures += 1;
    emit ConfirmTx(msg.sender, _txId);
    }

function revokeConfirmation(uint _txId) public onlyOwner txExists(_txId) notExecuted(_txId) {
    require(isConfirmed[_txId][msg.sender], "Not confirmed.");
    isConfirmed[_txId][msg.sender] = false;
    allTransactions[_txId].numSignatures -= 1;

    emit RevokeConfirmation(msg.sender, _txId);
}
    function executeTransaction(uint _txId) public txExists(_txId) notExecuted(_txId) onlyOwner {
    Transaction storage current_txn = allTransactions[_txId];
    require(current_txn.numSignatures >= required, "Not enough confirmations");

    (bool success, ) = current_txn.recipientAddress.call{value: current_txn.value}(current_txn.callData);
    require(success, "Transaction failed");

    current_txn.beenExecuted = true;

    emit ExecuteTx(msg.sender, _txId);


}

function getOwners() public view returns (address[] memory) {
    return owners;
}

function getTransactionCount() public view returns (uint256) {
    return allTransactions.length;
}

function getConfirmationCount(uint _txId) public view returns (uint) {
    return allTransactions[_txId].numSignatures;
}

function getTransaction(uint _txId) public view returns (address, uint, bytes memory, bool, uint) {
    Transaction storage txn = allTransactions[_txId];
    return (txn.recipientAddress, txn.value, txn.callData, txn.beenExecuted, txn.numSignatures);
    
}

receive() external payable {}
fallback() external payable {}


}