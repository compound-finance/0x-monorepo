/*

  Copyright 2019 ZeroEx Intl.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

*/

pragma solidity ^0.5.5;
pragma experimental ABIEncoderV2;

import "@0x/contracts-utils/contracts/src/LibBytes.sol";


library LibAssetData {
    bytes4 constant public ERC20_PROXY_ID = bytes4(keccak256("ERC20Token(address)"));

    function encodeERC20AssetData(address tokenAddress)
        public
        pure
        returns (bytes memory assetData)
    {
        return abi.encodeWithSelector(ERC20_PROXY_ID, tokenAddress);
    }

    function decodeERC20AssetData(bytes memory assetData)
        public
        pure
        returns (
            bytes4 proxyId,
            address tokenAddress
        )
    {
        proxyId = LibBytes.readBytes4(assetData, 0);

        require(proxyId == ERC20_PROXY_ID);

        tokenAddress = LibBytes.readAddress(assetData, 16);
    }
}
