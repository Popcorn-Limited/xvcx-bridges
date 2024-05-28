pragma solidity ^0.8.13;

import {CREATE3Script} from "./base/CREATE3Script.sol";
import {WormholeBridger} from "../src/WormholeBridger.sol";

contract SetChains is CREATE3Script {

    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() external {
        WormholeBridger bridger = WormholeBridger(0x3eBB62994e1442E60bBd6ad336bbbf2c16291C5B);

        uint deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address[] memory targetBridgers = vm.envAddress("TARGET_BRIDGERS", ",");
        uint16[] memory targetChainIds = uintArrToUint16Arr(
            vm.envUint("TARGET_CHAIN_IDS", ",")
        );
        address[] memory sourceBridgers = vm.envAddress("SOURCE_BRIDGERS", ",");
        uint16[] memory sourceChainIds = uintArrToUint16Arr(
            vm.envUint("SOURCE_CHAIN_IDS", ",")
        );
        vm.startBroadcast(deployerPrivateKey);

        bridger.setSourceChains(sourceChainIds, sourceBridgers);
        bridger.setTargetChains(targetChainIds, targetBridgers);

        vm.stopBroadcast();
    }

    /// @dev converts uint to uint16. If the given uint value is bigger
    // than uint16 it will overflow.
    function uintArrToUint16Arr(uint[] memory arr) internal pure returns (uint16[] memory) {
        uint16[] memory uint16Arr = new uint16[](arr.length);
        for (uint i; i < arr.length;) {
            uint16Arr[i] = uint16(arr[i]);
            unchecked {
                ++i;
            }
        }
    
        return uint16Arr;
    }
}
