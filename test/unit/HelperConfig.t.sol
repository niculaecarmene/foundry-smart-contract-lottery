// SDPX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";

contract HelperConfigTest is Test {

    HelperConfig helperConfig = new HelperConfig();

    function testInvalidChainId() public {
        vm.expectRevert(HelperConfig.HelperConfig_InvalidChainID.selector);
        helperConfig.getConfigByChainId(111);
    }

    function testGetOrCreateAnvilEthConfigPositive() public {
        HelperConfig.NetworkConfig memory localNetwork = helperConfig.getOrCreateAnvilEthConfig();

        assert(localNetwork.account == 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38);
    }
}