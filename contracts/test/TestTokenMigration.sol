pragma solidity 0.8.6;

import './helpers/TestBaseWorkflowV2.sol';
import './helpers/TestBaseWorkflowV1.sol';
import '../JBV3Token.sol';
import 'forge-std/Test.sol';
import '@jbx-protocol-v1/contracts/interfaces/ITicketBooth.sol';

contract TestTokenMigration is TestBaseWorkflowV2, TestBaseWorkflowV1 {
  address _projectOwner = address(0xf00ba6);
  uint256 _projectId;
  
  // v3 instances
  JBTokenStore _v3JbTokenStore;
  JBV3Token _v3Token;
  JBDirectory _v3jJbDirectory;
  JBController v3controller;

  // v2 instances
  JBController v2controller;
  JBProjectMetadata _projectMetadata;
  JBFundingCycleData _data;
  JBFundAccessConstraints[] _fundAccessConstraint;
  JBGroupedSplits[] _groupedSplits;
  JBFundingCycleMetadata _metadata;
  IJBPaymentTerminal[] _terminals; // Default empty
  JBSplitsStore _jbSplitsStore;

  function setUp() public override(TestBaseWorkflowV2, TestBaseWorkflowV1) {
    TestBaseWorkflowV2.setUp();

    v2controller = jbController();

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

    evm.prank(_projectOwner);
    v2controller.issueTokenFor(_projectId, 'v2 token', 'v2 token');

    // mimicing a v3 project launch since there was dependency issue with importing both v2 & v3 contract togethet since the almost every contract is the same
    _setupV3ProjectToMigrateTokensTo();
  }

  function _setupV3ProjectToMigrateTokensTo () internal {
    JBProjects _jbProjects = new JBProjects(jbOperatorStore());

    address preDeterministicJBDirectory = addressFrom(address(this), 15);

    // JBFundingCycleStore
    JBFundingCycleStore _jbFundingCycleStore = new JBFundingCycleStore(IJBDirectory(preDeterministicJBDirectory));

    // JBDirectory
    _v3jJbDirectory = new JBDirectory(jbOperatorStore(), _jbProjects, _jbFundingCycleStore, multisig());

    // JBTokenStore
    _v3JbTokenStore = new JBTokenStore(jbOperatorStore(), _jbProjects, _v3jJbDirectory);

    // JBSplitsStore
    JBSplitsStore _newJbSplitsStore = new JBSplitsStore(jbOperatorStore(), _jbProjects, _v3jJbDirectory);

    // JBController
    v3controller = new JBController(
      jbOperatorStore(),
      _jbProjects,
      _v3jJbDirectory,
      _jbFundingCycleStore,
      _v3JbTokenStore,
      _newJbSplitsStore
    );

    evm.prank(multisig());
    _v3jJbDirectory.setIsAllowedToSetFirstController(address(v3controller), true);

    // JBETHPaymentTerminalStore
    JBSingleTokenPaymentTerminalStore _jbPaymentTerminalStore = new JBSingleTokenPaymentTerminalStore(
      _v3jJbDirectory,
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
      _v3jJbDirectory,
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

   
    _metadata.allowMinting = true;

    // mimicing a v3 project launch since there was dependency issue with importing both v2 & v3 contract togethet since the almost every contract is the same
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

    assertEq(_jbProjects.ownerOf(_projectId), _projectOwner);
    
    // deploying v3 token
    _v3Token = new JBV3Token('v3 token', 'v3 token', _projectId, _v3jJbDirectory, ITicketBooth(address(0)), jbTokenStore());

  }

  function testMigrationWhenUseHasClaimedAndUnclaimedBalances() public {
    JBETHPaymentTerminal terminal = jbETHPaymentTerminal();
    address _user = address(bytes20(keccak256('user')));

    // fund user
    evm.deal(_user, 2 ether);
    
    // pay project and getting unclaimed token balance
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

    // pay project and getting claimed tokens sent
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
      true,
      /* _memo */
      'Take my money!',
      /* _delegateMetadata */
      new bytes(0)
    );

    assertEq(jbPaymentTerminalStore().balanceOf(terminal, _projectId), 2 ether);

    // giving all necessary permissions
    IJBToken _token = jbTokenStore().tokenOf(_projectId);
    evm.prank(_user);
    _token.approve(_projectId, address(_v3Token), 1000000 ether);

    uint256[] memory _transferPermissionIndex = new uint256[](1);
    _transferPermissionIndex[0] = JBOperations.TRANSFER;

    evm.prank(_user);
    jbOperatorStore().setOperator(
      JBOperatorData(address(_v3Token), _projectId, _transferPermissionIndex)
    );

    uint256[] memory _mintPermissionIndex = new uint256[](1);
    _mintPermissionIndex[0] = JBOperations.MINT;

    evm.prank(_projectOwner);
    jbOperatorStore().setOperator(
      JBOperatorData(address(_v3Token), _projectId, _mintPermissionIndex)
    );

    uint256 unclaimedBalance = jbTokenStore().unclaimedBalanceOf(_user, _projectId);
    uint256 claimedBalance = jbTokenStore().tokenOf(_projectId).balanceOf(_user, _projectId);

    evm.prank(_user);
    _v3Token.migrate();

    uint256 v3TokenBalance = _v3Token.balanceOf(_user, _projectId);
    assertEq(v3TokenBalance, unclaimedBalance + claimedBalance);
  }

    function testMigrationWhenUseHasNoClaimedAndUnclaimedBalances() public {
    address _user = address(bytes20(keccak256('user')));

    // fund user
    evm.deal(_user, 2 ether);

    IJBToken _token = jbTokenStore().tokenOf(_projectId);
    evm.prank(_user);
    _token.approve(_projectId, address(_v3Token), 1000000 ether);

    uint256[] memory _transferPermissionIndex = new uint256[](1);
    _transferPermissionIndex[0] = JBOperations.TRANSFER;

    evm.prank(_user);
    jbOperatorStore().setOperator(
      JBOperatorData(address(_v3Token), _projectId, _transferPermissionIndex)
    );

    uint256[] memory _mintPermissionIndex = new uint256[](1);
    _mintPermissionIndex[0] = JBOperations.MINT;

    evm.prank(_projectOwner);
    jbOperatorStore().setOperator(
      JBOperatorData(address(_v3Token), _projectId, _mintPermissionIndex)
    );

    evm.prank(_user);
    evm.expectRevert(abi.encodeWithSignature('INSUFFICIENT_FUNDS()'));
    _v3Token.migrate();
  }
}