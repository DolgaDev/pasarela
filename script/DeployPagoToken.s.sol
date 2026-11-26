// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {PagoToken} from "../src/PagoToken.sol";

contract DeployPagoToken is Script {
    uint256 constant INITIAL_SUPPLY = 1_000_000e6; // 1M USDG al deployer
    uint256 constant MAX_SUPPLY = 10_000_000e6; // tope de emisión: 10M USDG

    function run() external returns (PagoToken token) {
        vm.startBroadcast();
        (, address deployer,) = vm.readCallers();
        token = new PagoToken(deployer, INITIAL_SUPPLY, MAX_SUPPLY);
        vm.stopBroadcast();

        console.log("PagoToken desplegado en:", address(token));
        console.log("Owner:", token.owner());
        console.log("Supply inicial:", token.totalSupply());
        console.log("Cap:", token.cap());
    }
}
