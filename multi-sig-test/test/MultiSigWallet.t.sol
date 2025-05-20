// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/MultiSigWallet.sol";

contract MultiSigWalletTest is Test {
    MultiSigWallet wallet;
    address owner1 = address(0x1);
    address owner2 = address(0x2);
    address owner3 = address(0x3);
    address owner4 = address(0x4);
    address owner5 = address(0x5);
    address nonOwner = address(0x999);
    address[] owners;

    function setUp() public {
        owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        wallet = new MultiSigWallet(owners, 2);
    }

    function testOnlyOwnerCanSubmitTx() public {
        vm.prank(nonOwner);
        vm.expectRevert("Only owner.");
        wallet.submitTransaction((address(0xdead)), 1 ether, "");

    }

    function testDuplicateOwners() public {
        address[] memory duplicateOwners = new address[](3);
        duplicateOwners[0] = owner1;
        duplicateOwners[1] = owner2;
        duplicateOwners[2] = owner1;

        vm.expectRevert("Owner not unique");
        new MultiSigWallet(duplicateOwners, 2);
    }

    function testNonZeroAddressOwner() public {
        address[] memory zeroAddressOwners = new address[](3);
        zeroAddressOwners[0] = address(0);
        zeroAddressOwners[1] = owner2;
        zeroAddressOwners[2] = owner3;

        vm.expectRevert("Invalid owner");
        new MultiSigWallet(zeroAddressOwners, 2);
    }

    function testMaxOwnerLimit() public {
        address[] memory maxOwners = new address[](6);
        maxOwners[0] = owner1;
        maxOwners[1] = owner2;
        maxOwners[2] = owner3;
        maxOwners[3] = owner4;
        maxOwners[4] = owner5;
        maxOwners[5] = address(0x6);

        vm.expectRevert("Too many owners");
        new MultiSigWallet(maxOwners, 2);
    }

    function testCorrectTransactionStorage() public {
        address recipient = address(0xdead);
        uint256 value = 1 ether;
        bytes memory callData = "";
        uint256 txId = wallet.getTransactionCount();

        vm.expectEmit(true, true, true, true);
        emit MultiSigWallet.SubmitTx(owner1, txId, recipient, value, callData);

        vm.prank(owner1);
        wallet.submitTransaction(recipient, value, callData);
        (address to, uint256 amount, bytes memory data, bool executed, uint numConfirmations) = wallet.allTransactions(txId);

        assertEq(to, recipient);
        assertEq(amount, value);
        assertEq(data, callData);
        assertEq(numConfirmations, 0);
        assertEq(executed, false);
    }

    function testOnlyOwnerCanConfirm() public {
        vm.prank(nonOwner);
        vm.expectRevert("Only owner.");
        wallet.confirmTransaction(0);
    }

    function testOwnerCanConfirmOnce() public {
        vm.prank(owner1);
        wallet.submitTransaction(address(0xdead), 1 ether, "");

        uint txId = wallet.getTransactionCount() - 1;
        vm.expectEmit(true, true, true, true);
        emit MultiSigWallet.ConfirmTx(owner1, txId);

        vm.prank(owner1);
        wallet.confirmTransaction(txId);

        (,, , , uint numConfirmations) = wallet.allTransactions(txId);
        assertEq(numConfirmations, 1);

        vm.prank(owner1);
        vm.expectRevert("Already confirmed");
        wallet.confirmTransaction(txId);
    }

    function testConfirmTransaction() public {
        vm.prank(owner1);
        wallet.submitTransaction(address(0xdead), 1 ether, "");
        uint txId = wallet.getTransactionCount() - 1;

        vm.prank(owner1);
        wallet.confirmTransaction(txId);

        (,, , , uint numConfirmations) = wallet.allTransactions(txId);
        assertEq(numConfirmations, 1);
    }

    function testConfirmNonExistentTransaction() public {
        vm.prank(owner1);
        vm.expectRevert("No such transaction.");
        wallet.confirmTransaction(999);
    }

    function testConfirmExecutedTransaction() public {
        address recipient = address(0xdead);
        uint256 value = 1 ether;
        bytes memory callData = "";

        vm.prank(owner1);
        wallet.submitTransaction(recipient, value, callData);

        uint txId = wallet.getTransactionCount() - 1;

        vm.prank(owner1);
        wallet.confirmTransaction(txId);

        vm.prank(owner2);
        wallet.confirmTransaction(txId);

        vm.prank(owner1);
        vm.deal(address(wallet), 1 ether);
        wallet.executeTransaction(txId);
        (,,, bool executed,) = wallet.allTransactions(txId);
        assertEq(executed, true);

        vm.prank(owner3);

        vm.expectRevert("Already executed");
        wallet.confirmTransaction(txId);

    }

    function testConfirmationCount() public {
        vm.prank(owner1);
        wallet.submitTransaction(address(0xdead), 1 ether, "");
        uint txId = wallet.getTransactionCount() - 1;

        vm.prank(owner2);
        wallet.confirmTransaction(txId);
        vm.prank(owner3);
        wallet.confirmTransaction(txId);

        (, , , , uint numConfirmations) = wallet.allTransactions(txId);
        assertEq(numConfirmations, 2);

        uint actualConfirmations = 0;
        for (uint i = 0; i < owners.length; i++) {
            if (wallet.isConfirmed(txId, owners[i])) {
                actualConfirmations++;
            }
        }
        assertEq(numConfirmations, actualConfirmations);
    }

    function testRevokeOnceConfirmed() public {
        vm.prank(owner1);
        wallet.submitTransaction(address(0xdead), 1 ether, "");
        uint txId = wallet.getTransactionCount() - 1;

        vm.prank(owner1);
        wallet.confirmTransaction(txId);
        vm.prank(owner2);
        wallet.confirmTransaction(txId);

        vm.expectEmit(true, true, true, true);

        emit MultiSigWallet.RevokeConfirmation(owner1, txId);

        vm.prank(owner1);
        wallet.revokeConfirmation(txId);

        (, , , , uint numConfirmations) = wallet.allTransactions(txId);
        assertEq(numConfirmations, 1);
    }

    function testRevokeAnotherOwnersConfirmation() public {
        vm.prank(owner1);
        wallet.submitTransaction(address(0xdead), 1 ether, "");
        uint txId = wallet.getTransactionCount() - 1;

        vm.prank(owner1);
        wallet.confirmTransaction(txId);
        vm.prank(owner2);
        wallet.confirmTransaction(txId);

        vm.prank(owner3);
        vm.expectRevert("Not confirmed.");
        wallet.revokeConfirmation(txId);
    }

    function testExecuteTransactionOnceOnly() public {
        vm.prank(owner1);
        wallet.submitTransaction(address(0xdead), 1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);
        vm.prank(owner2);
        wallet.confirmTransaction(0);

        vm.prank(owner2);
        vm.deal(address(wallet), 1 ether);
        wallet.executeTransaction(0);

        (,,, bool executed,) = wallet.allTransactions(0);
        assertEq(executed, true);

        vm.expectRevert("Already executed");
        vm.prank(owner1);
        wallet.executeTransaction(0);

    }

    function testExecuteTx() public {
        vm.prank(owner1);
        wallet.submitTransaction(address(0xdead), 1 ether, "");
        uint txId = wallet.getTransactionCount() - 1;

        vm.prank(owner1);
        wallet.confirmTransaction(txId);
        vm.prank(owner2);
        wallet.confirmTransaction(txId);

        vm.expectEmit(true, true, true, true);
        emit MultiSigWallet.ExecuteTx(owner1, txId);
        
        vm.prank(owner1);
        vm.deal(address(wallet), 1 ether);
        wallet.executeTransaction(txId);

        (,,, bool executed,) = wallet.allTransactions(txId);
        assertEq(executed, true);
    }

    function testExecuteTransactionByNonOwner() public {
        vm.prank(owner1);
        wallet.submitTransaction(address(0xdead), 1 ether, "");
        uint txId = wallet.getTransactionCount() - 1;

        vm.prank(owner1);
        wallet.confirmTransaction(txId);
        vm.prank(owner2);
        wallet.confirmTransaction(txId);

        vm.prank(nonOwner);
        vm.expectRevert("Only owner.");
        wallet.executeTransaction(txId);
    }

    function testExecuteContractFunctionCall() public {
        Receiver receiver = new Receiver();
        bytes memory callData = abi.encodeWithSignature("storeData(uint256)", 42);

        vm.prank(owner1);
        wallet.submitTransaction(address(receiver), 0, callData);
        uint txId = wallet.getTransactionCount() - 1;

        vm.prank(owner1);
        wallet.confirmTransaction(txId);
        vm.prank(owner2);
        wallet.confirmTransaction(txId);
        vm.prank(owner1);
        wallet.executeTransaction(txId);
        assertEq(receiver.storedData(), 42);
    }

    function testRevertWithFailingCall() public {
        FailingContract badTarget = new FailingContract();
    
        bytes memory callData = abi.encodeWithSignature("willRevert()");

        vm.prank(owner1);
        wallet.submitTransaction(address(badTarget), 0, callData);
        uint txId = wallet.getTransactionCount() - 1;

        vm.prank(owner1);
        wallet.confirmTransaction(txId);
        vm.prank(owner2);
        wallet.confirmTransaction(txId);

        vm.expectRevert("Transaction failed");
        vm.prank(owner1);
        wallet.executeTransaction(txId);

        (,,, bool executed,) = wallet.allTransactions(txId);
        assertEq(executed, false);
    }
}

contract Receiver {
    uint256 public storedData;

    function storeData(uint256 _data) public {
        storedData = _data;
    }
}

contract FailingContract {
    function willRevert() public pure {
        require(false, "Always fails");
    }
}
