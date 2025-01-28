// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

// unit
// integration
// forked
// staging <- run tests on a mainnet or testnet

// fuzzing
// stateless fuzz
// stateful fuzz
// formal verification 

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {CreateChainlinkSubscription, FundChainLinkSubscription, ConsumerChainlink} from "script/Interactions.s.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {console} from "forge-std/console.sol";


contract InteractionsTest is CodeConstants, Test {

    CreateChainlinkSubscription private createSub = new CreateChainlinkSubscription();
    HelperConfig private helperConfig = new HelperConfig();
    FundChainLinkSubscription private fundSub = new FundChainLinkSubscription();

    function testDeployRaffle() public {
        DeployRaffle deployScript = new DeployRaffle();
        deployScript.run(); // Execute the `run` function in the script
    }

    function testCreateCLSubscriptionPositive() public {
        createSub.run();
    }

    function testCreateCLSubscriptionPositiveDirect() public {
        createSub.createSubscription(helperConfig.getConfig().vrfCoordinator, helperConfig.getConfig().account);
    }

    function testFundCLSubscriptionPositive() public {
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        // Create a new subscription
        uint256 subscriptionId = VRFCoordinatorV2_5Mock(config.vrfCoordinator).createSubscription();

        fundSub.fundingSubscription(config.vrfCoordinator, subscriptionId, config.link, config.account);

        // Add assertions to verify the subscription was funded successfully
        (uint96 balance, , , ,) = VRFCoordinatorV2_5Mock(config.vrfCoordinator).getSubscription(subscriptionId);
        console.log("Balance of subscription", balance);
        console.log("Balance of subscription", FUND_AMOUNT * 100);
        assert(balance == FUND_AMOUNT * 100);
    }
}