// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import { Script } from "forge-std/Script.sol";
import { InsureABag } from "../src/InsureABag.sol";

contract DeployInsureABag is Script {
    address internal deployer;
    InsureABag internal insureabag;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address apeEth = 0xb4c4a493AB6356497713A78FFA6c60FB53517c63;
        insureabag = new InsureABag("InsureABag", "IAB", apeEth);

        vm.stopBroadcast();
    }
}
