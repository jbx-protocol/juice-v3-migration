pragma solidity 0.8.6;

import './helpers/TestBaseWorkflow.sol';
import '../JBV3Token.sol';
import 'forge-std/Test.sol';
import '@jbx-protocol-v1/contracts/interfaces/ITicketBooth.sol';

contract TestTokenMigration is TestBaseWorkflow {
 address _projectOwner = address(0xf00ba6);

  uint256 _projectId;

  JBV3Token _v3Token;
  JBDirectory _jbDirectory;
  JBController v2controller;
  JBController v3controller;
  JBProjectMetadata _projectMetadata;
  JBFundingCycleData _data;
  JBFundAccessConstraints[] _fundAccessConstraint;
  JBGroupedSplits[] _groupedSplits;
  JBFundingCycleMetadata _metadata;
  IJBPaymentTerminal[] _terminals; // Default empty
  V2Allocator _v2Allocator;
  JBSplitsStore _jbSplitsStore;

  function setUp() public override {
     super.setUp();

    v2controller = jbController();

    _v2Allocator = v2Allocator();

    _jbSplitsStore = jbSplitsStore();

    _projectMetadata = JBProjectMetadata({content: 'myIPFSHash', domain: 1});

    _data = JBFundingCycleData({
      duration: 14,
      weight: 1000 * 10**18,
      discountRate: 450000000,
      ballot: IJBFundingCycleBallot(address(0))
    });

    _metadata = JBFundingCycleMetadata({
      global: JBGlobalFundingCycleMetadata({allowSetTerminals: false, allowSetController: false}),
      reservedRate: 5000, //50%
      redemptionRate: 5000, //50%
      ballotRedemptionRate: 0,
      pausePay: false,
      pauseDistributions: false,
      pauseRedeem: false,
      pauseBurn: false,
      allowMinting: false,
      allowChangeToken: false,
      allowTerminalMigration: false,
      allowControllerMigration: false,
      holdFees: false,
      useTotalOverflowForRedemptions: false,
      useDataSourceForPay: false,
      useDataSourceForRedeem: false,
      dataSource: address(0)
    });

    _terminals.push(jbETHPaymentTerminal());

    _fundAccessConstraint.push(JBFundAccessConstraints({
        terminal: jbETHPaymentTerminal(),
        token: jbLibraries().ETHToken(),
        distributionLimit: 0,
        overflowAllowance: 0,
        distributionLimitCurrency: jbLibraries().ETH(),
        overflowAllowanceCurrency: jbLibraries().ETH()
    }));

    // deploying a v2 project
    evm.prank(_projectOwner);
    _projectId = v2controller.launchProjectFor(
      _projectOwner,
      _projectMetadata,
      _data,
      _metadata,
      block.timestamp,
      _groupedSplits,
      _fundAccessConstraint,
      _terminals,
      ''
    );

    _setupProjectToMigrateTokensTo();
  }

  function _setupProjectToMigrateTokensTo () internal {
    JBProjects _jbProjects = new JBProjects(jbOperatorStore());

    address contractAtNoncePlusOne = addressFrom(address(this), 15);
    // address contractAtNoncePlusOne = computeCreateAddress(address(this), evm.getNonce(address(this)));

    // JBFundingCycleStore
    JBFundingCycleStore _jbFundingCycleStore = new JBFundingCycleStore(IJBDirectory(contractAtNoncePlusOne));
    // assertEq(evm.getNonce(address(this)), 10);

    // JBDirectory
    _jbDirectory = new JBDirectory(jbOperatorStore(), _jbProjects, _jbFundingCycleStore, multisig());

    // JBTokenStore
    JBTokenStore _jbTokenStore = new JBTokenStore(jbOperatorStore(), _jbProjects, _jbDirectory);

    // JBSplitsStore
    JBSplitsStore _newJbSplitsStore = new JBSplitsStore(jbOperatorStore(), _jbProjects, _jbDirectory);

    // JBController
    v3controller = new JBController(
      jbOperatorStore(),
      _jbProjects,
      _jbDirectory,
      _jbFundingCycleStore,
      _jbTokenStore,
      _newJbSplitsStore
    );

    evm.prank(multisig());
    _jbDirectory.setIsAllowedToSetFirstController(address(v3controller), true);

    // JBETHPaymentTerminalStore
    JBSingleTokenPaymentTerminalStore _jbPaymentTerminalStore = new JBSingleTokenPaymentTerminalStore(
      _jbDirectory,
      _jbFundingCycleStore,
      jbPrices()
    );

    // AccessJBLib
    AccessJBLib _accessJBLib = new AccessJBLib();

    // JBETHPaymentTerminal
    JBETHPaymentTerminal _jbETHPaymentTerminal = new JBETHPaymentTerminal(
      _accessJBLib.ETH(),
      jbOperatorStore(),
      _jbProjects,
      _jbDirectory,
      _newJbSplitsStore,
      jbPrices(),
      _jbPaymentTerminalStore,
      multisig()
    );

   IJBPaymentTerminal[] memory _newProjectterminals = new IJBPaymentTerminal[](1);
    _newProjectterminals[0] = (_jbETHPaymentTerminal);

    _fundAccessConstraint.push(JBFundAccessConstraints({
        terminal: _jbETHPaymentTerminal,
        token: jbLibraries().ETHToken(),
        distributionLimit: 0,
        overflowAllowance: 0,
        distributionLimitCurrency: jbLibraries().ETH(),
        overflowAllowanceCurrency: jbLibraries().ETH()
    }));

    // deploying a v2 project
    evm.prank(_projectOwner);
    _projectId = v3controller.launchProjectFor(
      _projectOwner,
      _projectMetadata,
      _data,
      _metadata,
      block.timestamp,
      _groupedSplits,
      _fundAccessConstraint,
      _newProjectterminals,
      ''
    );

    _v3Token = new JBV3Token('v3 token', 'v3 token', _projectId, _jbDirectory, ITicketBooth(address(0)), jbTokenStore());
  }

  function testMigration() public {
    JBETHPaymentTerminal terminal = jbETHPaymentTerminal();
    address _user = address(bytes20(keccak256('user')));

    // fund user
    evm.deal(_user, 1 ether);
    
    // pay project
    evm.prank(_user);
    terminal.pay{value: 1 ether}(
      _projectId,
      1 ether,
      address(0),
      /* _beneficiary */
      _user,
      /* _minReturnedTokens */
      0,
      /* _preferClaimedTokens */
      false,
      /* _memo */
      'Take my money!',
      /* _delegateMetadata */
      new bytes(0)
    );

    assertEq(jbPaymentTerminalStore().balanceOf(terminal, _projectId), 1 ether);

    evm.prank(_user);
    _v3Token.migrate();
  }
}