// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;


import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";
import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";

contract RaffleTest is CodeConstants, Test{

    Raffle public raffle;
    HelperConfig public helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;
    uint256 constant SEND_VALUE_LOW = 0.01 ether; // Example value
    uint256 constant SEND_VALUE = 0.02 ether;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gaseLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    /**
     * EVENTS - copied from Raffle.sol
     */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    modifier setPlayerAndAddFunds() {
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE); // Allocate 1 ETH to PLAYER
        _;
    }

    modifier raffleEnter() {
        raffle.enterRaffle{value:entranceFee}();
        // Cheat code to change the timestamp during testing
        vm.warp(block.timestamp + interval+1);
        // Cheat code to change the block number during testing
        vm.roll(block.number + 1);
        _;
    }

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval; 
        vrfCoordinator = config.vrfCoordinator;
        gaseLane = config.gaseLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
    }

    /** ---- TEST RAFFLE FUNCTION ---- */


    function testIsOpen() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    
    function testEnterRaffleNotEnoughEth() public setPlayerAndAddFunds {
        // Arrange: Set up a mock player - this happens in the modifier

        // Expect revert with the correct error selector
        vm.expectRevert(Raffle.Raffle_SendMoreETHToEnter.selector);

        // Act: Attempt to enter raffle with insufficient ETH
        raffle.enterRaffle{value: SEND_VALUE_LOW}();
    }

    function testRaffleRecordsNewPlayer() public setPlayerAndAddFunds {
        // Arrange: Set up a mock player - this happens in the modifier

        // Act - player wants to enter raffle
        raffle.enterRaffle{value: SEND_VALUE}();

        // Asset - check if the player is added
        address playerRecord = raffle.getPlayer(0);
        assert (playerRecord == PLAYER);
    }

    function testEngineeringRaffleEmitEvent() public setPlayerAndAddFunds{
        // Arrange - Set up a mock player - this happens in the modifier

        // Act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        // Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    function testNotAllowedPlayersWhenCalculating() public setPlayerAndAddFunds raffleEnter{
        // 1. Arrange - Set up a mock player - setPlayerAndAddFunds

        // 2. Act - raffleEnter

        raffle.performUpkeep("");
        // 3. Assert
        vm.expectRevert(Raffle.Raffle_RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
    }

    /** ---- TEST CHECKUPKEEP FUNCTION ---- */
    function testCheckUpKeepNoBlanceReturnFalse() public {
        // 1. Arrange
        // Cheat code to change the timestamp during testing
        vm.warp(block.timestamp + interval+1);
        // Cheat code to change the block number during testing
        vm.roll(block.number + 1); 

        // 2. Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // 3. Assert
        assert (upkeepNeeded == false);
    }

    function testCheckUpkeepRaffleNotOpenReturnFalse() public setPlayerAndAddFunds {
        // 1. Arrange
        raffle.enterRaffle{value: entranceFee}();
        // Cheat code to change the timestamp during testing
        vm.warp(block.timestamp +2);
        // Cheat code to change the block number during testing
        vm.roll(block.number + 1); 

        // 2. Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // 3. Assert
        assert (!upkeepNeeded);
    }

    /**
     * * [testCheckUpkeepReturnsTrueWhenParametersGood]
     */
    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public setPlayerAndAddFunds {
        // 1. Arrange
        raffle.enterRaffle{value: entranceFee}();

        // 2. Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // 3. Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersGood() public setPlayerAndAddFunds raffleEnter{
        // 1. Arrange - in the modifiers

        // 2. Act
        (bool upkeepNeede, ) = raffle.checkUpkeep("");

        // 3. Assert
        assert(upkeepNeede);
    }

    /** ---- TEST PERFORMUPKEEP FUNCTION ---- */
    function testPerformUpkeepOnlyWhenCheckUpkeepTrue() public setPlayerAndAddFunds raffleEnter{
        // 1. Arrange - raffleEnter 

        // 2. Act / 3. Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepWhenCheckUpkeepFalse() public setPlayerAndAddFunds {
        // 1. Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState state = raffle.getRaffleState();    
        
        // 2. Act / 3. Assert
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle_UpkeepNotneeded.selector, currentBalance, numPlayers, state));
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public setPlayerAndAddFunds raffleEnter{
        // Arrange - raffleEnter

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // requestId = raffle.getLastRequestId();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1); // 0 = open, 1 = calculating
    }

    /** ---- TEST FULLFILLRANDOMWORDS FUNCTION ---- */
    modifier skipFork {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testFullFillRandomwordsCalledONLYAfterPerformUpkeep(uint256 requestId) public setPlayerAndAddFunds raffleEnter {
        // 1. Arrange 2. Act - set in modifiers
        // 3. Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(requestId, address(raffle));
    }

    function testFullfillRandomWordsPicksAWinnerAndSendsMoney() public setPlayerAndAddFunds raffleEnter skipFork{
        // 1. Arrange
        // add 3 more players, 4 in total
        uint256 addPlayers = 3;
        uint256 startIndex = 1;
        address expectedWinner = address(1);

        for (uint256 i = startIndex; i < addPlayers + 1; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startTimestamp = raffle.getLastTimestamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // 2. Act
        console.log("Calling performUpkeep...");
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        console.log("Number of log entries:", entries.length);

        // Ensure there are enough log entries
        require(entries.length > 1, "Not enough log entries emitted");

        bytes32 requestId = entries[1].topics[1];
        console.log("Request ID:", uint256(requestId));

        // Debug: Check contract balance before fulfillRandomWords
        uint256 contractBalanceBeforeFulfill = address(raffle).balance;
        console.log("Contract balance before fulfillRandomWords:", contractBalanceBeforeFulfill);

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // 3. Assert
        console.log("Checking assertions...");

        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState state = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endTimeStamp = raffle.getLastTimestamp();
        uint256 prize = entranceFee * (addPlayers+1);

        // Debug: Check contract balance after fulfillRandomWords
        uint256 contractBalanceAfter = address(raffle).balance;
        console.log("Contract balance after fulfillRandomWords:", contractBalanceAfter);

        assert(recentWinner == expectedWinner);
        assert(uint256(state) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endTimeStamp > startTimestamp);

        console.log("Test completed successfully.");
    }
}