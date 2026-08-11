// What are our invariants?

// 1. The total supply of DSC should be less than the total value of collateral in the system. (backing collateralization)
// 2. Getter view functions should never revert. (view functions should never revert)

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract OpenInvariantsTest is StdInvariant, Test  {

  DSCEngine dscEngine;
  DeployDSC deployer;
  DecentralizedStableCoin dsc;
  HelperConfig config;
  address weth;
  address btc;

  function setUp() external {
    deployer = new DeployDSC();
    (dsc, dscEngine, config) = deployer.run();
    (,, weth, btc,) = config.activeNetworkConfig();
    targetContract(address(dscEngine));
  }

  function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
    uint256 totalSupply = dsc.totalSupply();
    uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dscEngine));
    uint256 totalBtcDeposited = IERC20(btc).balanceOf(address(dscEngine));
    
    uint256 wethValue = dscEngine.getUsdValue(weth, totalWethDeposited);
    uint256 btcValue = dscEngine.getUsdValue(btc, totalBtcDeposited);
    uint256 totalValue = wethValue + btcValue;

    assert(totalValue >= totalSupply);
  }
}
   