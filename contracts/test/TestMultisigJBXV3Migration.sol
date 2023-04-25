// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@jbx-protocol-v2/contracts/interfaces/IJBOperatorStore.sol";
import "@jbx-protocol-v2/contracts/interfaces/IJBTokenStore.sol";

import "../JBV3Token.sol";
import "@jbx-protocol-v1/contracts/interfaces/ITickets.sol";
import "@jbx-protocol-v1/contracts/interfaces/IOperatorStore.sol";

import "forge-std/Test.sol";

/**
 *  @title  JBX migration to V3 test - mainnet fork
 */
contract TestMultisigJBXV3Migration_Fork is Test {
    address multisig = 0xAF28bcB48C40dBC86f52D459A6562F658fc94B1e;

    // V1
    ITickets tickets = ITickets(0x3abF2A4f8452cCC2CF7b4C1e4663147600646f66);
    ITicketBooth ticketBooth = ITicketBooth(0xee2eBCcB7CDb34a8A822b589F9E8427C24351bfc );

    // V2
    IOperatorStore operatorStore = IOperatorStore(0xab47304D987390E27Ce3BC0fA4Fe31E3A98B0db2);
    IJBOperatorStore jbOperatorStore = IJBOperatorStore(0x6F3C5afCa0c9eDf3926eF2dDF17c8ae6391afEfb);
    IJBTokenStore jbV2TokenStore = IJBTokenStore(0xCBB8e16d998161AdB20465830107ca298995f371);

    // V3
    IJBTokenStore jbV3TokenStore = IJBTokenStore(0x6FA996581D7edaABE62C15eaE19fEeD4F1DdDfE7);

    // Migration
    JBV3Token jbV3Token = JBV3Token(0x4554CC10898f92D45378b98D6D6c2dD54c687Fb2);

    function setUp() public {
        vm.createSelectFork("https://rpc.ankr.com/eth", 17125699);
    }

    /**
     * @notice  V1 and V2 balance should be migrated to V3
     */
    function testMigration_migrateV1AndV2ToV3() public {
        /**
            JBP-371:
            Call v1 OperatorStore.setOperator(...) with an _operator of JBV3Token, a _domain of 1, and a _permissionIndexes of [12] (Transfer).
            Call v2 JBOperatorStore.setOperator with an operator of JBV3Token, a domain of 1, and a permissionIndexes of 12 (Transfer).
            Call Tickets.approve(...) on v1 JBX with a spender of JBV3Token and the maximum amount (the maximum UINT256, 2**256 - 1).
            Call JBV3Token.migrate().
        */
        uint256 _v1Jbx = tickets.balanceOf(multisig)+ ticketBooth.stakedBalanceOf(multisig, 1) - ticketBooth.lockedBalanceOf(multisig, 1);
        uint256 _v2Jbx = jbV2TokenStore.balanceOf(multisig, 1);
        uint256 _v3Jbx = jbV3TokenStore.balanceOf(multisig, 1);

        vm.startPrank(multisig);

        // First step
        uint256[] memory _permissionIndexes = new uint256[](1);
        _permissionIndexes[0] = 12;
        operatorStore.setOperator(address(jbV3Token), 1, _permissionIndexes);

        // Second step
        JBOperatorData memory _operatorData = JBOperatorData({
            operator: address(jbV3Token),
            domain: 1,
            permissionIndexes: _permissionIndexes
        });
        jbOperatorStore.setOperator(_operatorData);

        // Third step
        tickets.approve(address(jbV3Token), type(uint256).max);

        // Fourth step
        jbV3Token.migrate();

        // Check: v3 = v1 + ticket + v2 ?
        assertEq(jbV3TokenStore.balanceOf(multisig, 1), _v1Jbx + _v2Jbx + _v3Jbx, "wrong final v3 supply");

        // Check: v1 == v2 == 0 ?
        assertEq(tickets.balanceOf(multisig), 0, "wrong final v1 supply");
        assertEq(ticketBooth.stakedBalanceOf(multisig, 1), 0, "wrong final v1 ticket supply");
        assertEq(jbV2TokenStore.balanceOf(multisig, 1), 0, "wrong final v2 supply");
    }
}
