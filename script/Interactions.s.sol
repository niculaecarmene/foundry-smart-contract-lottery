// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {console} from "forge-std/console.sol";

contract CreateChainlinkSubscription is Script {

    function createChainLinkSubscriptionUsingConfig() public returns(uint256, address){
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinatorAdr = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        (uint256 subId,) = createSubscription(vrfCoordinatorAdr, account);

        return (subId, vrfCoordinatorAdr);
    }

    function createSubscription(address vrfCoordinatorAdr, address account) public returns(uint256, address){
        console.log("Create subscription on chain id:", block.chainid);
        
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinatorAdr).createSubscription();
        vm.stopBroadcast();

        console.log("Your subscription id is:", subId);
        console.log("Please update your subscription id in the HelperConfig.s.sol");

        return (subId, vrfCoordinatorAdr);
    }

    function run() public{
        createChainLinkSubscriptionUsingConfig();
    }
}

contract FundChainLinkSubscription is Script, CodeConstants {
    

    function fundingSubscriptionUsingConfig() public{
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinatorAdr = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address linktokenAdr = helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;

        fundingSubscription(vrfCoordinatorAdr, subscriptionId, linktokenAdr, account);
    }

    function fundingSubscription(address vrfCoordinatorAdr, uint256 subscriptionId, 
            address linkTokenAdr, address account) public{
        console.log("Using vrfCoordinator address:", vrfCoordinatorAdr);
        console.log("Funding subscription:", subscriptionId);
        console.log("On chain id:", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinatorAdr).fundSubscription(subscriptionId, FUND_AMOUNT*100);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
            LinkToken(linkTokenAdr).transferAndCall(vrfCoordinatorAdr, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }

    function run() public{
        fundingSubscriptionUsingConfig();
    }
}

contract ConsumerChainlink is Script{

    function addConsumerUsingConfig(address mostRecentDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinatorAdr = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address account = helperConfig.getConfig().account;

        addConsumer( mostRecentDeployed, vrfCoordinatorAdr, subscriptionId, account);
    }

    function addConsumer(address contractToAddToVrfChainlink, address vrfCoordinatorAdr, 
        uint256 subId, address account) public {
        console.log("Adding consumer contract:", contractToAddToVrfChainlink);
        console.log("To vrfCoordinator:", vrfCoordinatorAdr);
        console.log("On Chainid:", block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinatorAdr).addConsumer(subId, contractToAddToVrfChainlink);
        vm.stopBroadcast();
    }

    function run() public {
        address mostRecentDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentDeployed);
    }
}