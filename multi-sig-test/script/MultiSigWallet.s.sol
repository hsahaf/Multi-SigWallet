// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "forge-std/Script.sol";
import "../src/MultiSigWallet.sol";
import "forge-std/console.sol";


contract MultiSigWalletScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address[] memory owners = new address[](3);
        owners[0] = address(0x1);
        owners[1] = address(0x2);
        owners[2] = address(0x3);
        uint256 required = 2;
        MultiSigWallet wallet = new MultiSigWallet(owners, required);
        console.log("MultiSigWallet deployed at:", address(wallet))

        vm.stopBroadcast();

    }
}