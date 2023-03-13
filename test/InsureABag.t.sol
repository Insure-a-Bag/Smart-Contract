// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { InsureABag } from "src/InsureABag.sol";

contract InsureABagTest is PRBTest, StdCheats {
    InsureABag public insureabag;

    address public owner;
    uint256 public ownerPkey;

    address public minter1;
    address public minter2;
    address public minter3;

    string public name = "InsureABag";
    string public symbol = "IAB";


    function setUp() public {
        (owner, ownerPkey) = makeAddrAndKey("owner");

        vm.deal(minter1, 20 ether);
        vm.deal(minter2, 20 ether);
        vm.deal(minter3, 20 ether);

        vm.prank(owner);
        insureabag = new InsureABag("InsureABag", "IAB");
    }

    function testDeployment() public {
        assertEq(insureabag.name(), name);
        assertEq(insureabag.symbol(), symbol);
        assertEq(insureabag.owner(), owner);
    }
}
