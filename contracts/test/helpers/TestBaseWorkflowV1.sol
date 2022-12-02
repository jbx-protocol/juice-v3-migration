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
import '@jbx-protocol-v1/contracts/interfaces/IModStore.sol';
import '@jbx-protocol-v1/contracts/interfaces/IFundingCycles.sol';
import '@jbx-protocol-v1/contracts/interfaces/ITerminalV1_1.sol';
import '@jbx-protocol-v1/contracts/interfaces/ITreasuryExtension.sol';
import '@jbx-protocol-v1/contracts/interfaces/IFundingCycleBallot.sol';
import '@jbx-protocol-v1/contracts/libraries/Operations.sol';
import '@jbx-protocol-v1/contracts/interfaces/ITickets.sol';

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

      PayoutMod[] memory _payoutMod = new PayoutMod[](0);
      TicketMod[] memory _ticketMod = new TicketMod[](0);

      _terminal = new TerminalV1_1(_projects, _fundingCycles, _ticketBooth, _operatorStore, _modStore, _prices, _terminalDirectory, _multisig);

      FundingCycleProperties memory _fundingCycleProperties = FundingCycleProperties({
        target: 2 ether,
        currency: 0,
        duration: 14,
        cycleLimit: 2,
        discountRate: 200,
        ballot: IFundingCycleBallot(address(0))
      });

      FundingCycleMetadata2 memory _metadata = FundingCycleMetadata2({
        reservedRate: 0,
        bondingCurveRate: 200,
        reconfigurationBondingCurveRate: 200,
        payIsPaused: false,
        ticketPrintingIsAllowed: true,
        treasuryExtension: ITreasuryExtension(address(0))
      });

    // deploying a 3 v1 projects to make sure the project id is diff than v2 & v3 project id so v1 project id would be 3
      _terminal.deploy(
        _multisig,
        bytes32("deploy 1st project"),
        "deploy 1st project",
        _fundingCycleProperties,
        _metadata,
        _payoutMod,
        _ticketMod
      );

      _terminal.deploy(
        _multisig,
        bytes32("deploy 2nd project"),
        "deploy 2nd project",
        _fundingCycleProperties,
        _metadata,
        _payoutMod,
        _ticketMod
      );
      
      _terminal.deploy(
        _multisig,
        bytes32("deploy 3rd project"),
        "deploy 3rd project",
        _fundingCycleProperties,
        _metadata,
        _payoutMod,
        _ticketMod
      );

      // issue token
      vm.prank(_multisig);
      _ticketBooth.issue(3, 'v1 token', 'v1 token');
  }

}