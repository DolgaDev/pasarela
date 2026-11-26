# USDG (DolgaToken): datos del token

Token ERC-20 para la pasarela de pagos, desplegado y verificado en **Base Sepolia**.

## Datos principales

| Dato | Valor |
|---|---|
| Red | Base Sepolia |
| Chain ID | `84532` |
| Dirección del contrato | `0x7054f7fB18f2f1942eE2B4dB91B48a809F50900F` |
| Nombre | `DolgaToken` |
| Símbolo | `USDG` |
| Decimales | `6` (1 USDG = 1.000.000 unidades mínimas) |
| Suministro inicial | 1.000.000 USDG (`1000000000000`), acuñado al owner en el deploy |
| Tope de emisión (`cap`) | 10.000.000 USDG (`10000000000000`), inmutable |
| Owner / deployer | `0xeecEf32c9092D40feF16f18d4429230C9bE2fecf` |
| Contrato fuente | `src/PagoToken.sol:PagoToken` |
| Estándares / extensiones | ERC-20, ERC-2612 (`permit`), `ERC20Capped`, `Ownable` (OpenZeppelin 5.6.1) |
| Compilador | Solidity 0.8.39 (Foundry) |

## Explorador y verificación

| Recurso | Enlace |
|---|---|
| Blockscout (código verificado, Read/Write contract) | https://base-sepolia.blockscout.com/address/0x7054f7fB18f2f1942eE2B4dB91B48a809F50900F |
| Basescan | https://sepolia.basescan.org/address/0x7054f7fB18f2f1942eE2B4dB91B48a809F50900F |
| Sourcify | https://repo.sourcify.dev/84532/0x7054f7fB18f2f1942eE2B4dB91B48a809F50900F |

- Verificación: **Sourcify, `exact_match`** (coinciden el bytecode de creación, el de runtime y los metadatos).
- Argumentos del constructor (ABI-encoded):

```
0x000000000000000000000000eecef32c9092d40fef16f18d4429230c9be2fecf000000000000000000000000000000000000000000000000000000e8d4a51000000000000000000000000000000000000000000000000000000009184e72a000
```

Que corresponden a `constructor(address initialOwner, uint256 initialSupply, uint256 maxSupply)` =
`(0xeecEf32c9092D40feF16f18d4429230C9bE2fecf, 1000000000000, 10000000000000)`.

## Deploy

| Dato | Valor |
|---|---|
| Tx de deploy | `0xc45efb862ea5324aec748b7fb4e652d705b905a5e29c5bea2c0916e5e636c024` |
| Bloque | `63683698` |
| Estado | 1 (success) |
| Gas usado | 1.977.109 |
| Script | `script/DeployPagoToken.s.sol` |

## Transacciones de prueba (Parte G)

| Operación | Bloque | Tx |
|---|---|---|
| `transfer` 100 USDG a `0x…dEaD` | 63688745 | `0xf943c7663f7b03b485b4d47ae86c1dbc07b6ec04ed3f8c654ef7619161c6d373` |
| `approve` 50 USDG a `0x…dEaD` | 63688899 | `0xda2efa550593ccdb46af6b9eb1df968729873401b81f52b120a13dbce9ca6bd4` |
| `mint` 1.000 USDG al owner | 63689037 | `0xc9200a83e86b6dd36ce3c1dd687d2142e35810c5e54a76be82d8168b3a90aab6` |

## Estado on-chain (26/11/2026)

| Función | Valor | Equivale a |
|---|---|---|
| `totalSupply()` | `1001000000000` | 1.001.000 USDG |
| `cap()` | `10000000000000` | 10.000.000 USDG |
| `balanceOf(owner)` | `1000900000000` | 1.000.900 USDG |
| `balanceOf(0x…dEaD)` | `100000000` | 100 USDG |
| `allowance(owner, 0x…dEaD)` | `50000000` | 50 USDG |
| `DOMAIN_SEPARATOR()` | `0x7d4a88fdb07a6e4e9088613090fcd9c0bed83598fec40933c03fe6f25197c32a` | Dominio EIP-712 del permit |

## Cómo consultarlo

Con Foundry (`cast`), sin necesidad de wallet:

```bash
TOKEN=0x7054f7fB18f2f1942eE2B4dB91B48a809F50900F
RPC=https://sepolia.base.org

cast call $TOKEN "name()(string)" --rpc-url $RPC
cast call $TOKEN "symbol()(string)" --rpc-url $RPC
cast call $TOKEN "decimals()(uint8)" --rpc-url $RPC
cast call $TOKEN "totalSupply()(uint256)" --rpc-url $RPC
cast call $TOKEN "cap()(uint256)" --rpc-url $RPC
cast call $TOKEN "owner()(address)" --rpc-url $RPC
cast call $TOKEN "balanceOf(address)(uint256)" 0xeecEf32c9092D40feF16f18d4429230C9bE2fecf --rpc-url $RPC
```

Eventos `Transfer` desde el deploy. El RPC `sepolia.base.org` limita `eth_getLogs` a 200 bloques, así que se usa otro:

```bash
cast logs --address $TOKEN "Transfer(address indexed from, address indexed to, uint256 value)" \
  --from-block 63683698 --rpc-url https://base-sepolia-rpc.publicnode.com
```

### Agregarlo a MetaMask

Red Base Sepolia → *Importar token* → dirección `0x7054f7fB18f2f1942eE2B4dB91B48a809F50900F`, símbolo `USDG`, decimales `6`.

## Funciones del contrato

| Función | Acceso | Descripción |
|---|---|---|
| `transfer`, `approve`, `transferFrom` | Cualquiera | ERC-20 estándar |
| `permit(owner, spender, value, deadline, v, r, s)` | Cualquiera | Aprobación por firma EIP-2612 |
| `nonces(owner)`, `DOMAIN_SEPARATOR()` | Lectura | Soporte de `permit` |
| `mint(to, amount)` | Solo owner | Acuña tokens; revierte si se supera `cap()` |
| `cap()` | Lectura | Tope máximo de emisión |
| `owner()`, `transferOwnership`, `renounceOwnership` | Owner | `Ownable` de OpenZeppelin |

Errores relevantes (OpenZeppelin 5): `ERC20InsufficientBalance`, `ERC20InsufficientAllowance`, `ERC20ExceededCap`, `OwnableUnauthorizedAccount`, `ERC2612ExpiredSignature`, `ERC2612InvalidSigner`.

## Decisiones de diseño

- **6 decimales:** es un token de pagos y sigue la convención de USDC/USDT.
- **`mint` con tope:** la pasarela necesita emitir después del deploy. `ERC20Capped` acota el riesgo de que el owner (o quien robe su clave) emita sin límite.
- **`permit` (EIP-2612):** permite aprobar con una firma off-chain, sin que el usuario pague gas por el `approve`.

## Tests

`forge test --match-contract PagoTokenTest`: **14 tests, 14 pasan**, incluido 1 fuzz de 256 corridas. Cubren el supply inicial, `approve`/`transferFrom`, el control de acceso de `mint`, el evento `Transfer`, `ERC20InsufficientBalance`, `permit` (válido, vencido y replay) y el tope de emisión. Código en `test/PagoToken.t.sol`.
