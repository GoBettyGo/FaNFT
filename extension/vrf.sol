
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

abstract contract vrfContract is VRFConsumerBaseV2(0xc587d9053cd1118f25F645F9E08BB98c9712A4EE){
    // Chainklink VRF V2
    VRFCoordinatorV2Interface immutable COORDINATOR=VRFCoordinatorV2Interface(0xc587d9053cd1118f25F645F9E08BB98c9712A4EE);
    uint32 public callbackGasLimit;
    uint16 public requestConfirmations;
    uint16 constant numWords = 1;

    mapping(uint256 => address) internal requestIdToAddress;
    mapping(address => uint256) internal batchSeed;
    mapping(address => uint256) public requestVRFCount;

    event RandomnessRequest(uint256 requestId);

    constructor() {

    }

    function __init_VrfContract(uint32 _callbackGasLimit,uint16 _requestConfirmations) internal{
        callbackGasLimit = _callbackGasLimit;
        requestConfirmations = _requestConfirmations;
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 randomness = randomWords[0];
        address requestAddress = requestIdToAddress[requestId];
        delete requestIdToAddress[requestId];
        batchSeed[requestAddress] = randomness;
        _processRandomnessFulfillment(requestId, requestAddress, randomness);
    }

    function _requestVRF() internal {
        uint256 requestId = COORDINATOR.requestRandomWords(
            _keyHash(),
            _subscriptionId(),
            requestConfirmations,
            callbackGasLimit,
            numWords
        );

        emit RandomnessRequest(requestId);
        requestIdToAddress[requestId] = msg.sender;
        requestVRFCount[msg.sender]+=1;
        _processRandomnessRequest(requestId, msg.sender);
    }

    function _keyHash() internal virtual returns (bytes32);

    function _subscriptionId() internal virtual returns (uint64);

    function _processRandomnessRequest(uint256 requestId, address requestAddress) internal virtual {}

    function _processRandomnessFulfillment(uint256 requestId, address requestAddress, uint256 randomness) internal virtual {}

    function seed(address requestAddress) internal view returns (uint256){
        uint256 _batchSeed = batchSeed[requestAddress];
        require(_batchSeed != 0, "RandomSeed: Randomness hasn't been fullfilled.");
        return uint256(keccak256(
                abi.encode(_batchSeed, block.timestamp)
            ));
    }

    function seedToRandom(uint256 randomness) internal view returns (uint256){
        require(randomness != 0, "RandomSeed: Randomness hasn't been fullfilled.");
        return uint256(keccak256(
                abi.encode(randomness, block.timestamp)
            ));
    }
}
