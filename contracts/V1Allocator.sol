// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {IJBDirectory as IJBDirectoryV3} from '@jbx-protocol-v3/contracts/interfaces/IJBDirectory.sol';
import {IJBPaymentTerminal as IJBPaymentTerminalV3} from '@jbx-protocol-v3/contracts/interfaces/IJBPaymentTerminal.sol';
import '@jbx-protocol-v1/contracts/interfaces/IModAllocator.sol';
import {JBTokens as JBTokensV3} from '@jbx-protocol-v3/contracts/libraries/JBTokens.sol';
import '@openzeppelin/contracts/utils/introspection/ERC165.sol';

/**
  @notice
  Juicebox split allocator for allocating V1 treasury funds to a V3 treasury

  @dev
  Adheres to -
  IModAllocator: Adhere to Allocator pattern to receive payout distributions for allocation. 

  @dev
  Inherits from -
  ERC165: Introspection on interface adherance. 
*/
contract V1Allocator is ERC165, IModAllocator {
  //*********************************************************************//
  // --------------------------- custom errors ------------------------- //
  //*********************************************************************//

  error TERMINAL_NOT_FOUND();

  //*********************************************************************//
  // --------------------- public stored properties -------------------- //
  //*********************************************************************//

  /**
    @notice
    The V3 directory address.
  */
  IJBDirectoryV3 public immutable directory;

  /**
    @param _directory The V3 directory address. 
  */
  constructor(IJBDirectoryV3 _directory) {
    directory = _directory;
  }

  /**
    @notice
    Allocate hook that will transfer treasury funds to V3.

    @param _projectId The project ID where the funds are being transferred from. This is unused.
    @param _forProjectId The project ID where the funds will be transferred to.
    @param _beneficiary The address that should be the beneficiary of the allocation. This is unused.
  */
  function allocate(
    uint256 _projectId,
    uint256 _forProjectId,
    address _beneficiary
  ) external payable override {
    _projectId; // Prevents unused var compiler and natspec complaints.
    _beneficiary; // Prevents unused var compiler and natspec complaints.

    // Get the ETH payment terminal for the destination project in the V3 directory.
    IJBPaymentTerminalV3 _terminal = directory.primaryTerminalOf(_forProjectId, JBTokensV3.ETH);

    // Make sure there is an ETH terminal.
    if (address(_terminal) == address(0)) revert TERMINAL_NOT_FOUND();

    // Add the funds to the balance of the V3 terminal.
    _terminal.addToBalanceOf{value: msg.value}(
      _forProjectId,
      msg.value,
      JBTokensV3.ETH,
      'v1 -> v3 allocation',
      bytes('')
    );
  }

  function supportsInterface(bytes4 _interfaceId) public view override returns (bool) {
    return _interfaceId == type(IModAllocator).interfaceId || super.supportsInterface(_interfaceId);
  }
}
