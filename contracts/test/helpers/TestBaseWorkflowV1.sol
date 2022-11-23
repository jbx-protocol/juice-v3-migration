pragma solidity 0.8.6;

import 'ds-test/test.sol';
import 'forge-std/Vm.sol';

import '@jbx-protocol-v1/contracts/Projects.sol';
import '@jbx-protocol-v1/contracts/OperatorStore.sol';
import '@jbx-protocol-v1/contracts/TerminalV1_1.sol';
import '@jbx-protocol-v1/contracts/FundingCycles.sol';
import '@jbx-protocol-v1/contracts/TerminalDirectory.sol';
import '@jbx-protocol-v1/contracts/TicketBooth.sol';
import '@jbx-protocol-v1/contracts/ModStore.sol';
import '@jbx-protocol-v1/contracts/Prices.sol';


contract TestBaseWorkflowV1 is DSTest {

  // Multisig address used for testing.
  address private _multisig = address(456);

  // EVM Cheat codes - test addresses via prank and startPrank in hevm
  Vm public vm = Vm(HEVM_ADDRESS);

  // JBOperatorStore
  Projects private _projects;

  OperatorStore private _operatorStore;

  TerminalV1_1 private _terminal;

  FundingCycles private _fundingCycles;

  TerminalDirectory private _terminalDirectory;

  TicketBooth private _ticketBooth;

  ModStore private _modStore;

  Prices private _prices;

  //*********************************************************************//
  // ------------------------- internal views -------------------------- //
  //*********************************************************************//

  function projects() internal view returns (Projects) {
    return _projects;
  }

  function operatorStore() internal view returns (OperatorStore) {
    return _operatorStore;
  }

  function terminal() internal view returns (TerminalV1_1) {
    return _terminal;
  }

  function fundingCycles() internal view returns (FundingCycles) {
    return _fundingCycles;
  }

  function terminalDirectory() internal view returns (TerminalDirectory) {
    return _terminalDirectory;
  }

  function ticketBooth() internal view returns (TicketBooth) {
    return _ticketBooth;
  }

  function modStore() internal view returns (ModStore) {
    return _modStore;
  }

  function prices() internal view returns (Prices) {
    return _prices;
  }

  //*********************************************************************//
  // --------------------------- test setup ---------------------------- //
  //*********************************************************************//

  // Deploys and initializes contracts for testing.
  function setUp() public virtual {

      _operatorStore = new OperatorStore();

      _projects = new Projects(_operatorStore);

      _terminalDirectory = new TerminalDirectory(_projects, _operatorStore);

      _fundingCycles = new FundingCycles(_terminalDirectory);

      _ticketBooth = new TicketBooth(_projects, _operatorStore, _terminalDirectory);

      _prices = new Prices();

      _modStore = new ModStore(_projects, _operatorStore, _terminalDirectory);

      _terminal = new TerminalV1_1(_projects, _fundingCycles, _ticketBooth, _operatorStore, _modStore, _prices, _terminalDirectory, _multisig);
  }

}