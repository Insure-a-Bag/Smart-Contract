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

        address apeEth = 0x239d5b78680e9AD600Ab41E56508670BA9E78F51;
        address ape = 0x239d5b78680e9AD600Ab41E56508670BA9E78F51;

        insureabag = new InsureABag("InsureABag", "IAB", ape, apeEth);

        vm.stopBroadcast();
    }
}
