// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample of Raffle contract
 * @author Carmen Niculae (Bickel)
 * @notice A sample of a raffle contract
 * @dev Implements chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /**
     * ERRORS
     */
    error Raffle_SendMoreETHToEnter();
    error Raffle_TransferFailed();
    error Raffle_RaffleNotOpen();
    error Raffle_UpkeepNotneeded(uint256 balance, uint256 playersLength, uint256 raffleState);

    /**
     * TYPE DECLARATIONS
     */
    enum RaffleState {
        OPEN,           //0
        CALCULATING     //1
    }

    /**
     * STATE VARIABLES
     */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    // @dev the duration of lottary in seconds
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    uint256 private s_lastTimestamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /**
     * EVENTS
     */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gaseLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gaseLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {

        if (msg.value < i_entranceFee) {
            revert Raffle_SendMoreETHToEnter();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle_RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));
        //1. Makes migration easier
        //2. Makes front end indexies easier

        emit RaffleEntered(msg.sender);
    }

    /**
     * CALLED BY CHAINLINK
     * CHAINLINK - checks if the time to run pickWinner() is up
     * The follow rules should apply:
     * 1. The time interval has passed between raffles
     * 2. The loterry is open
     * 3. The contract has ETH
     * 4. There is at least one subscriber
     * 5. The subscription has LINK
     * @return upkeepNeeded true if is time to start to lottery, otherwise ignore
     */
    function checkUpkeep(bytes memory /** Check Data */) 
        public 
        view
        returns(bool upkeepNeeded, bytes memory /* performData */)
    {
        bool timeHasPassed = ((block.timestamp - s_lastTimestamp) >= i_interval);
        bool isOpen = (s_raffleState == RaffleState.OPEN);
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");
    }

    /**
     * CALLED BY CHAINLINK
     * 1. Get a randomn number, that is the maximum of players
     * 2. Select the winner
     * 3. Run the raffle automatically
     */
    function performUpkeep(bytes calldata /* performData */) external {
        
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle_UpkeepNotneeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;

        //Get the random number from ChainLink 2.5
        //1. Request the RN
        //2. Get the RN
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

        emit RequestedRaffleWinner(requestId);
    }

    // CEI: CHECKS, EFFECT, INTERACTIONS patterns
    function fulfillRandomWords(uint256, /* requestId */ uint256[] calldata randomWords) internal override {
        //** CHECKS - similar to modifiers */

        //** EFFECTS - internal contract states changes */
        //Since NUM_WORDS is set to 1, we will have only one randomWords
        uint256 indexOfWinner = randomWords[0]%s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimestamp = block.timestamp;
        emit WinnerPicked(winner);

        //** INTERACTIONS - external contract interactions */
        (bool success,) = winner.call{value: address(this).balance}("");
        if (!success){
            revert Raffle_TransferFailed();
        }
    }

    /**
     * Getter Functions
     */
    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getLastTimestamp() external view returns (uint256) {
        return s_lastTimestamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
