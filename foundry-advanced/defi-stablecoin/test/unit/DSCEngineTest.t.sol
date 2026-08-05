// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;
    address ethUsdPriceFeed;
    address weth;

    address USER = makeAddr("user");
    uint256 constant AMOUNT_COLLATERAL = 10 ether;
    uint256 constant AMOUNT_TO_MINT = 10 ether;

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, engine, config) = deployer.run();
        (ethUsdPriceFeed, , weth, , ) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, AMOUNT_TO_MINT);
    }

    function testGetUsdValue() public view{
      uint256 ethAmount = 15e18;
      uint256 expectedUsd = 30000e18;
      uint256 actualUsd = engine.getUsdValue(weth, ethAmount);
      assertEq(expectedUsd, actualUsd);
    }

    function testRevertIfCollateralZero() public {
      vm.startPrank(USER);
      ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

      vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
      engine.depositCollateral(weth, 0);
      vm.stopPrank();
    } 
}