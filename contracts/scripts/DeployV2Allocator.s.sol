// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '../V2Allocator.sol';
import 'forge-std/Script.sol';


contract Deploy_V2_Allocator_On_Mainnet is Script {

    IJBDirectory jbV3Directory = IJBDirectory(0x65572FB928b46f9aDB7cfe5A4c41226F636161ea);
    V2Allocator v2Allocator;

    function run() external {
      vm.startBroadcast();

      v2Allocator = new V2Allocator(jbV3Directory);
      console.log(address(v2Allocator));
    }
}

contract Deploy_V2_Allocator_On_Goerli is Script {

    IJBDirectory jbV3Directory = IJBDirectory(0x8E05bcD2812E1449f0EC3aE24E2C395F533d9A99);
    V2Allocator v2Allocator;

    function run() external {
      vm.startBroadcast();

      v2Allocator = new V2Allocator(jbV3Directory);
      console.log(address(v2Allocator));
    }
}