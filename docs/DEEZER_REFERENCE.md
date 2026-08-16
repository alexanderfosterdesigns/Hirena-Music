# Deezer Integration Reference (reverse-engineered & verified)

> Captured from the current, maintained deemix/deezer-sdk source (GPL-3.0).
> This is the authoritative spec for the Hirena gateway. Do not edit from memory.

## 1. Authentication (ARL)

1. Set cookie `arl=<token>` on domain `.deezer.com` (HttpOnly).
2. `POST http://www.deezer.com/ajax/gw-light.php` with **query params**:
   - `api_version=1.0`
   - `api_token=null` (only for `deezer.getUserData`)
   - `input=3`
   - `method=deezer.getUserData`
   - JSON body `{}`
3. Validate: `results.USER.USER_ID != 0`.
4. Extract ONLY:
   - `results.checkForm` → the `api_token` for all subsequent gw-light calls.
   - `results.USER.OPTIONS.license_token` → for `media.deezer.com/v1/get_url`.
   - tier flags: `USER.OPTIONS.web_hq` / `mobile_hq` (MP3_320), `web_lossless` / `mobile_lossless` (FLAC).
   - `USER.OPTIONS.license_country`.
   - Discard everything else (privacy firewall — ARL is a streaming key only).
5. All other gw-light calls use the same URL with `api_token=<checkForm>` and a JSON body of method-specific args.

User-Agent used by deemix:
`Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.130 Safari/537.36`

## 2. gw-light methods (catalog)

| Method | Args (JSON body) | Returns |
| --- | --- | --- |
| `deezer.getUserData` | `{}` | checkForm, USER, OPTIONS.license_token |
| `song.getData` | `{SNG_ID}` | single track (GWTrack) |
| `deezer.pageTrack` | `{SNG_ID}` | page; `DATA` = track |
| `song.getListData` | `{SNG_IDS:[...]}` | `data[]` (batch, keeps order) |
| `song.getLyrics` | `{SNG_ID}` | lyrics |
| `album.getData` | `{ALB_ID}` | album |
| `deezer.pageAlbum` | `{ALB_ID, lang:"en", header:true, tab:0}` | album page |
| `song.getListByAlbum` | `{ALB_ID, nb:-1}` | `data[]` album tracks |
| `artist.getData` | `{ART_ID}` | artist |
| `deezer.pageArtist` | `{ART_ID, lang:"en", header:true, tab:0}` | artist page |
| `artist.getTopTrack` | `{ART_ID, nb}` | `data[]` top tracks |
| `album.getDiscography` | `{ART_ID, discography_mode:"all", nb, nb_songs:0, start}` | discography |
| `deezer.pagePlaylist` | `{PLAYLIST_ID, lang:"en", header:true, tab:0}` | playlist page |
| `playlist.getSongs` | `{PLAYLIST_ID, nb:-1}` | `data[]` playlist tracks |
| `deezer.pageSearch` | `{query, start, nb, suggest, artist_suggest, top_tracks}` | unified search |
| `search.music` | `{query, filter:"ALL", output:<type>, start, nb}` | typed search |
| `page.get` | query param `gateway_input` JSON | home/editorial pages |

## 3. Track fields (GWTrack, from `song.getData` / `deezer.pageTrack.DATA`)

`SNG_ID, SNG_TITLE, DURATION, MD5_ORIGIN (hex string), MEDIA_VERSION, TRACK_TOKEN,
TRACK_TOKEN_EXPIRE, FILESIZE_MP3_128/MP3_256/MP3_320/FLAC, ALB_ID, ALB_TITLE,
ALB_PICTURE (md5), ART_ID, ART_NAME, ART_PICTURE (md5), GAIN, GENRE_ID, ISRC,
EXPLICIT_LYRICS, PHYSICAL_RELEASE_DATE, DISK_NUMBER, TRACK_NUMBER, RANK_SNG`

## 4. Stream URL resolution

### 4a. Primary — `media.deezer.com/v1/get_url`
`POST https://media.deezer.com/v1/get_url` (JSON body):
```json
{
  "license_token": "<license_token>",
  "media": [{"type":"FULL","formats":[{"cipher":"BF_CBC_STRIPE","format":"MP3_320"}]}],
  "track_tokens": ["<TRACK_TOKEN>"]
}
```
Response: `data[].media[].sources[].url` (signed CDN URL). Empty sources / error code
`2002` = geolocked; missing = license/tier mismatch (fall back MP3_320 → MP3_128).

### 4b. Fallback — `cdns-proxy` (deemix "old method", needs only track fields)
```
urlPart = MD5_ORIGIN + 0xA4 + format + 0xA4 + SNG_ID + 0xA4 + MEDIA_VERSION
md5val  = md5(urlPart) hex
step2   = md5val + 0xA4 + urlPart + 0xA4
step2  += "." repeated until len % 16 == 0
path    = AES-128-ECB(key="jo6aey6haid2Teih", step2, no padding).hex().lowercase()
URL     = "https://e-cdns-proxy-" + MD5_ORIGIN[0] + ".dzcdn.net/mobile/1/" + path
```
Formats (numeric): `MP3_128=1, MP3_320=3, FLAC=9, MP4_RA3=15, MP4_RA2=14, MP4_RA1=13, DEFAULT=8, LOCAL=0`.

## 5. Audio stream decryption ("BF_CBC_STRIPE")

Key derivation (`generateBlowfishKey(trackId)`):
```
SECRET = "g4el58wc0zvf9na1"                    // 16 ASCII bytes
idMd5  = md5( decimalString(trackId) ) hex     // 32 chars
key[i] = ascii(idMd5[i]) XOR ascii(idMd5[i+16]) XOR ascii(SECRET[i])   // i in 0..16
// 16 raw bytes
```

Block decrypt (`decryptChunk`): **Blowfish-CBC**, key = 16 raw bytes,
IV = `00 01 02 03 04 05 06 07`, **no padding**, block = 2048 bytes.

Stripe pattern: encrypted stream is processed in **6144-byte windows**; within each
window only the **first 2048-byte block** is encrypted, the next 4096 bytes are plaintext.
Equivalently: block index `i` (0-based, 2048-byte units) is encrypted iff `i % 3 == 0`.
Tail flush: if remaining >= 2048, decrypt first 2048, pass the rest; else pass through.

> Random access: a byte at offset `x` needs only its own 2048-byte block (fixed IV, no
> chaining). Seek = fetch the aligned block via HTTP Range, decrypt if `block_idx % 3 == 0`.

## 6. Artwork

- Cover: `https://e-cdns-images.dzcdn.net/images/cover/{md5}/{size}x{size}-000000-80-0-0.jpg`
- Artist: `https://e-cdns-images.dzcdn.net/images/artist/{md5}/{size}x{size}-000000-80-0-0.jpg`
- Sizes: 56, 250, 500, 1000.

## 7. Verified golden vectors

### 7a. Blowfish key derivation
| track_id | idMd5 (md5 of decimal string) | key hex (16 bytes) |
| --- | --- | --- |
| 3135556 | 29a15fc70fb278009ab6988ce9a422e8 | 6c6c666b39662c37652575603c643439 |
| 137955757 | 57ed5f11c325e1cb0e097df8ae96edeb | 62663031373a206a322c7d65393b6731 |

### 7b. Blowfish-CBC stream block (2048 bytes)
- key hex `6c6c666b39662c37652575603c643439`, IV `0001020304050607`, no padding
- plaintext = bytes `(i*7+3) & 0xFF` for i in 0..2048 (md5 `23398bb02c75378fb86bf1b62d860dee`)
- ciphertext md5 `78889b15f34d82d5582ee3491c97278c`
- **Cross-checked identical across OpenSSL 3.x (`bf-cbc`, legacy provider), the
  egoroof-blowfish JS lib (deemix fallback), and the raw-16-byte key interpretation.**

### 7c. AES-128-ECB stream path (fallback URL)
- sngID `3135556`, MD5_ORIGIN `e94eb1dc104d24a6ad96f0a1a0a2d0a2`, mediaVersion `0`, format `3`
- `md5val = 48bff4566896fcf852cf48ab1d1df4e1`
- encrypted path hex =
  `f2fffb0f43dfc3e4dd4a200b7d1a68fcf662bac9035a395e444608ddc3c6f33e77669f7da33fb9609081b54ac9f2e1082e7380d37b3adefca97e42a0b1ddb9bcdfc79bba5700431b98ebd3522f101497`
- URL `https://e-cdns-proxy-e.dzcdn.net/mobile/1/<path>`
