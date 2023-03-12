// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import { Script } from "forge-std/Script.sol";
import { InsureABag } from "../src/InsureABag.sol";

contract DeployInsureABag is Script {
    address internal deployer;
    InsureABag internal insureabag;

    function setUp() public virtual {
        string memory mnemonic = vm.envString("MNEMONIC");
        (deployer,) = deriveRememberKey(mnemonic, 0);
    }

    function run() public {
        vm.startBroadcast(deployer);

        insureabag = new InsureABag("InsureABag", "IAB");

        vm.stopBroadcast();
    }
}
