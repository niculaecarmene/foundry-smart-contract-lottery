// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateChainlinkSubscription, FundChainLinkSubscription, ConsumerChainlink} from "script/Interactions.s.sol";

contract DeployRaffle is Script{

    function run() public {
        deployContract();
    }

    function deployContract() public returns(Raffle, HelperConfig){
        HelperConfig helperconfig = new HelperConfig();
        // local    -> deploy mocks, get local config
        // sepolia  -> get sepolia config
        HelperConfig.NetworkConfig memory config = helperconfig.getConfig();

        // Create the subscription ID, in case it is not created - CHAINLINK
        if (config.subscriptionId == 0) {
            CreateChainlinkSubscription chainlinkSubscription = new CreateChainlinkSubscription();
            (config.subscriptionId, config.vrfCoordinator) = 
                chainlinkSubscription.createSubscription(config.vrfCoordinator, config.account);
        }

        // Fund the susbcription ID above, in case it is not funded - CHAINLINK
        FundChainLinkSubscription fundSubscription = new FundChainLinkSubscription();
        fundSubscription.fundingSubscription(config.vrfCoordinator, config.subscriptionId, config.link, config.account);

        vm.startBroadcast(config.account);

        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gaseLane,
            config.subscriptionId,
            config.callbackGasLimit
        );

        vm.stopBroadcast();

        // Add the consumer -contract address that will be called by chainlink
        ConsumerChainlink consumerChainLink = new ConsumerChainlink();
        consumerChainLink.addConsumer(address(raffle), config.vrfCoordinator, config.subscriptionId, config.account);

        return (raffle, helperconfig);
    }
}