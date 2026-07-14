// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevopsTools.sol";
import {BasicNft} from "../src/BasicNft.sol";

contract MintBasickNft is Script {

  
  
string public constant PUG = "ipfs://bafybeig37ioir76s7mg5oobetncojcm3c3hxasyd4rvid4jqhy4gkaheg4/?filename=0-PUG.json";

  function run() external {
    address mostRecentDeployed = DevOpsTools.get_most_recent_deployment("BasicNft", block.chainid);
    mintNftOnContract(mostRecentDeployed);
  }

  function mintNftOnContract(address nftContract) internal {
    vm.startBroadcast();
    BasicNft(nftContract).mintNft(PUG);
    vm.stopBroadcast();
  }
}