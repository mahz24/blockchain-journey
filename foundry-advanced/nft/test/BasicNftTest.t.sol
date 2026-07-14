// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {BasicNft} from "../src/BasicNft.sol";
import {DeployBasicNft} from "../script/DeployBasicNft.s.sol";

contract BasicNftTest is Test {
  BasicNft basicNft;
  DeployBasicNft deployer;
  address public USER = makeAddr('user');
  string public constant PUG = "ipfs://bafybeig37ioir76s7mg5oobetncojcm3c3hxasyd4rvid4jqhy4gkaheg4/?filename=0-PUG.json";



  function setUp() public {
    deployer = new DeployBasicNft();
    basicNft = deployer.run();
  }

  function testNameIsCorrect() public view {
    string memory name = basicNft.name();
    string memory expected = "Dogie";
    assertEq(name, expected);
  }

  function testCanMintAndHaveABalance() public {
    vm.prank(USER);
    basicNft.mintNft(PUG);
    assertEq(basicNft.balanceOf(USER), 1);
    assertEq(basicNft.tokenURI(0), PUG);
  }
}