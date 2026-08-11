
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract Handler is Test {

    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;

    ERC20Mock weth;
    ERC20Mock btc;

    uint256 public timesMintIsCalled;

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;
        address[] memory collateralTokens = dscEngine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        btc = ERC20Mock(collateralTokens[1]);
    }
    
    function mintDsc(uint256 amountDscToMint) public {
        

        (uint256 totalDscMinted, uint256 collateralValueInUsd,) = dscEngine.getAccountInformation(msg.sender);

        uint256 maxDscToMint = (collateralValueInUsd / 2) - totalDscMinted;
        if(maxDscToMint < 0) {
          return;
        }
        amountDscToMint = bound(amountDscToMint, 0, maxDscToMint);
        if(amountDscToMint == 0) return;

        vm.startPrank(msg.sender);
        dscEngine.mintDsc(amountDscToMint);
        vm.stopPrank();
        timesMintIsCalled++;
    }

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
      ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
      amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

      vm.startPrank(msg.sender);
      collateral.mint(msg.sender, amountCollateral);
      collateral.approve(address(dscEngine), amountCollateral);
      dscEngine.depositCollateral(address(collateral), amountCollateral);
      vm.stopPrank();
    }
    
    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
      ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
      uint256 maxCollateralToRedeem = dscEngine.getCollateralBalanceOfUser(address(collateral), msg.sender);
      amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);

      if (amountCollateral == 0) {
          return;
      }

      dscEngine.redeemCollateral(address(collateral), amountCollateral);
    }

    function _getCollateralFromSeed(uint256 seed) private view returns (ERC20Mock) {
        if (seed % 2 == 0) {
            return weth;
        } else {
            return btc;
        }
    }
}