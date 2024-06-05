pragma solidity ^0.8.13;
import {CREATE3Script} from "./base/CREATE3Script.sol";

import {WormholeBridger} from "../src/WormholeBridger.sol";

contract DeployWormholeBridger is CREATE3Script {

    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() external returns (address wormholeBridger) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address admin = vm.envAddress("ADMIN");
        address wormholeRelayer = vm.envAddress("WORMHOLE_RELAYER");
        address xVCX = vm.envAddress("XVCX");

        vm.startBroadcast(deployerPrivateKey);
        wormholeBridger = createx.deployCreate3(
            getCreate3ContractSalt("WormholeBridger"),
            bytes.concat(
                type(WormholeBridger).creationCode,
                abi.encode(xVCX, wormholeRelayer, admin)
            )
        );
    
        vm.stopBroadcast();
    }
}