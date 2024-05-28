pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {WormholeBridger} from "../src/WormholeBridger.sol";

import {IXERC20} from "../src/interfaces/IXERC20.sol";

contract WormholeBridgerTest is Test {
    address constant wormholeRelayer = 0x27428DD2d3DD32A4D7f7C497eAaa23130d894911;
    IXERC20 constant xVCX = IXERC20(0x18445923592be303fbd3BC164ee685C7457051b4);
    WormholeBridger bridger;

    address user = makeAddr("user");
    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        bridger = new WormholeBridger(
            address(xVCX),
            wormholeRelayer,
            address(this)
        );

        uint16[] memory chainIds = new uint16[](1);
        chainIds[0] = 23;
        address[] memory bridgers = new address[](1);
        // not important since we don't interact with that address
        bridgers[0] = address(1);
        bridger.setSourceChains(chainIds, bridgers);
        bridger.setTargetChains(chainIds, bridgers);

        vm.startPrank(0x22f5413C075Ccd56D575A54763831C4c27A37Bdb);
        xVCX.setLimits(address(bridger), type(uint).max, type(uint).max);
        xVCX.setLimits(address(this), type(uint).max, type(uint).max);
        vm.stopPrank();

        vm.prank(user);
        xVCX.approve(address(bridger), type(uint).max);

        // give user ETH to pay bridge fee
        deal(user, 100e18);
    }

    function test_onlyOwnerCanSetTargetChains() public {
        uint16[] memory chainIds = new uint16[](1);
        chainIds[0] = 23;
        address[] memory bridgers = new address[](1);
        // not important since we don't interact with that address
        bridgers[0] = address(1);
        vm.startPrank(user);
        vm.expectRevert("UNAUTHORIZED");
        bridger.setTargetChains(chainIds, bridgers);
        vm.stopPrank();

        bridger.setTargetChains(chainIds, bridgers);
    }

    function test_onlyOwnerCanSetSourceChains() public {
        uint16[] memory chainIds = new uint16[](1);
        chainIds[0] = 23;
        address[] memory bridgers = new address[](1);
        // not important since we don't interact with that address
        bridgers[0] = address(1);
        vm.prank(user);
        vm.expectRevert("UNAUTHORIZED");
        bridger.setSourceChains(chainIds, bridgers);

        bridger.setSourceChains(chainIds, bridgers);
    }

    function test_bridgingBurnsxVCX() public {
        xVCX.mint(user, 1e18);

        uint cost = bridger.quoteDeliveryCost(23);
        vm.prank(user);
        bridger.bridge{value: cost}(23, user, 1e18);

        assertEq(xVCX.balanceOf(user), 0, "didn't burn user's tokens");
    }

    function test_cannotBridgeToUnknownDestination() public {
        vm.prank(user);
        vm.expectRevert("unknown target chain");
        bridger.bridge{value: 1e18}(1, user, 1e18);
    }

    function test_shouldRefundExcessFunds() public {
        xVCX.mint(user, 1e18);

        uint initialBalance = user.balance;
        uint cost = bridger.quoteDeliveryCost(23);
        vm.prank(user);
        bridger.bridge{value: cost + 1e18}(23, user, 1e18);

        assertEq(user.balance, initialBalance - cost, "didn't refund excess funds");
    }

    function test_receiveWormholeMessages_onlyRelayerCanCall() public {
        bytes[] memory messages;
        vm.prank(user);
        vm.expectRevert("UNAUTHORIZED");
        bridger.receiveWormholeMessages("", messages, bytes32(0), 0, bytes32(0));
    }

    function test_receiveWormholeMessages_onlyKnownSourceChainCanCall() public {
        bytes memory payload = abi.encode(user, 100e18);
        bytes[] memory messages;
        vm.startPrank(wormholeRelayer);
        vm.expectRevert("unknown source chain");
        bridger.receiveWormholeMessages(payload, messages, bytes32(0), 0, bytes32(0));
        vm.expectRevert("unknown source chain");
        bridger.receiveWormholeMessages(payload, messages, bytes32(uint(uint160(address(2)))), 23, bytes32(0));
        vm.expectRevert("unknown source chain");
        bridger.receiveWormholeMessages(payload, messages, bytes32(uint(uint160(address(1)))), 1, bytes32(0));

        bridger.receiveWormholeMessages(payload, messages, bytes32(uint(uint160(address(1)))), 23, bytes32(0));
    }

    function test_receiveWormholeMessages_shouldMintTokens() public {
        bytes memory payload = abi.encode(user, 100e18);
        bytes[] memory messages;
        vm.startPrank(wormholeRelayer);

        uint gas = gasleft();
        bridger.receiveWormholeMessages(payload, messages, bytes32(uint(uint160(address(1)))), 23, bytes32(0));
        console.log("gas spent: ", gas - gasleft());
        
        assertEq(xVCX.balanceOf(user), 100e18);
    }
}