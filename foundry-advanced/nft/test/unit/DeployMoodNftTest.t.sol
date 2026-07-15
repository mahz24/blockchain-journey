// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DeployMoodNft} from "../../script/DeployMoodNft.s.sol";

contract DeployMoodNftTest is Test {
    DeployMoodNft public deployMoodNft;

    function setUp() public {
        deployMoodNft = new DeployMoodNft();
    }

    function testSvgToImageUri() public {
        string memory expectedUri = "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI1MDAiIGhlaWdodD0iNTAwIj48dGV4dCB4PSI1MCUiIHk9IjUwJSIgZG9taW5hbnQtYmFzZWxpbmU9Im1pZGRsZSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1zaXplPSIyNCIgZmlsbD0iYmxhY2siPkhlbGxvLCBTVkchIDwvdGV4dD48L3N2Zz4=";
        string memory svg = '<svg xmlns="http://www.w3.org/2000/svg" width="500" height="500"><text x="50%" y="50%" dominant-baseline="middle" text-anchor="middle" font-size="24" fill="black">Hello, SVG! </text></svg>';
        string memory imageUri = deployMoodNft.svgToImageUri(svg);
        emit log(imageUri);
        assertEq(imageUri, expectedUri);
    }
}