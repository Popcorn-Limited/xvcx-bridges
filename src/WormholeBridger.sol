pragma solidity ^0.8.13;

import {Owned} from "@solmate/auth/Owned.sol";

import {IWormholeRelayer} from "./interfaces/IWormholeRelayer.sol";
import {IWormholeReceiver} from "./interfaces/IWormholeReceiver.sol";
import {IXERC20} from "./interfaces/IXERC20.sol";

contract WormholeBridger is Owned, IWormholeReceiver {
    uint constant GAS_LIMIT = 75_000;

    IWormholeRelayer immutable relayer;
    IXERC20 immutable xVCX;

    /// @dev wormhole chain id => Wormhole bridger contract address on that chain
    // chains to which we can send xVCX
    mapping(uint16 => address) public targetChains;
    /// @dev wormhole chain id => Wormhole bridger contract address on that chain
    // chains from which we can receive xVCX
    mapping(uint16 => address) public sourceChains;

    constructor(
        address _xVCX,
        address _relayer,
        address _admin
    ) Owned(_admin) {
        xVCX = IXERC20(_xVCX);
        relayer = IWormholeRelayer(_relayer);
    }

    function setSourceChains(uint16[] calldata chainIds, address[] calldata bridgers) external onlyOwner {
        require(chainIds.length == bridgers.length, "input length doesn't match");
        for (uint i; i < chainIds.length;) {
            sourceChains[chainIds[i]] = bridgers[i];
            unchecked {
                ++i;
            }
        }
    }

    function setTargetChains(uint16[] calldata chainIds, address[] calldata bridgers) external onlyOwner {
        require(chainIds.length == bridgers.length, "input length doesn't match");
        for (uint i; i < chainIds.length;) {
            targetChains[chainIds[i]] = bridgers[i];
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev expects to receive enough ETH in call to cover the delivery cost.
     * Can get the necessary amount by calling `quoteDeliveryCost()`.
     * We don't check whether the given amount of ETH is enough to save gas.
     * Any bridge tx that doesn't provide the exact amount of ETH to cover the fee will revert.
     * @param chainId the chain to which to bridge the xVCX
     * @param to the recipient address on the other chain 
     * @param amount the amount of xVCX to bridge
     */
    function bridge(uint16 chainId, address to, uint amount) external payable {
        require(targetChains[chainId] != address(0), "unknown target chain");
        xVCX.burn(msg.sender, amount);

        uint cost = quoteDeliveryCost(chainId);
        require(msg.value >= cost, "not enough ETH");

        relayer.sendPayloadToEvm{value: cost}(
            chainId, 
            targetChains[chainId],
            abi.encode(to, amount),
            0,
            GAS_LIMIT,
            chainId,
            to
        );

        if (msg.value > cost) {
            (bool success, ) = payable(to).call{value: msg.value - cost}("");
            require(success, "refund failed");
        }
    }

    function quoteDeliveryCost(uint16 chainId) public view returns (uint cost) {
        (cost, ) = relayer.quoteEVMDeliveryPrice(
            chainId,
            0,
            GAS_LIMIT
        );
    }

    // we never send any native tokens to the other chain when bridging so we expect,
    // msg.value to always be 0 here.
    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory additionalMessages,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 deliveryHash
    ) external payable override {
        if (msg.sender != address(relayer)) {
            revert("UNAUTHORIZED");
        }
        if (sourceAddress == bytes32(0) || sourceChains[sourceChain] != address(uint160(uint256(sourceAddress)))) {
            revert("unknown source chain");
        }

        (address to, uint amount) = abi.decode(payload, (address, uint));
        xVCX.mint(to, amount);
    }

}