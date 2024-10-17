;; PixelVault NFT Marketplace Smart Contract

;; Define constants
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-listing-not-found (err u102))
(define-constant err-invalid-price (err u103))
(define-constant err-invalid-token-id (err u104))
(define-constant err-invalid-uri (err u105))
(define-constant err-invalid-royalty (err u106))

;; Define NFT asset
(define-non-fungible-token pixelvault uint)

;; Define data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var next-token-id uint u1)

;; Define data maps
(define-map tokens
  { token-id: uint }
  { owner: principal, creator: principal, uri: (string-utf8 256), royalty: uint }
)

(define-map listings
  { token-id: uint }
  { price: uint, seller: principal }
)

;; Private function to check contract ownership
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Transfer contract ownership
(define-public (transfer-contract-ownership (new-owner principal))
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (ok (var-set contract-owner new-owner))
  )
)

;; Get current contract owner
(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

;; Mint new NFT
(define-public (mint (uri (string-utf8 256)) (royalty uint))
  (let
    (
      (token-id (var-get next-token-id))
    )
    (asserts! (> (len uri) u0) err-invalid-uri) ;; Check if URI is not empty
    (asserts! (<= royalty u1000) err-invalid-royalty) ;; Ensure royalty is not more than 100% (1000 basis points)
    (try! (nft-mint? pixelvault token-id tx-sender))
    (map-set tokens
      { token-id: token-id }
      { owner: tx-sender, creator: tx-sender, uri: uri, royalty: royalty }
    )
    (var-set next-token-id (+ token-id u1))
    (ok token-id)
  )
)

;; List NFT for sale
(define-public (list-nft (token-id uint) (price uint))
  (let
    (
      (token-owner (unwrap! (nft-get-owner? pixelvault token-id) err-invalid-token-id))
    )
    (asserts! (> price u0) err-invalid-price) ;; Check if price is greater than 0
    (asserts! (is-eq tx-sender token-owner) err-not-token-owner)
    (map-set listings
      { token-id: token-id }
      { price: price, seller: tx-sender }
    )
    (ok true)
  )
)

;; Cancel NFT listing
(define-public (cancel-listing (token-id uint))
  (let
    (
      (listing (unwrap! (map-get? listings { token-id: token-id }) err-listing-not-found))
    )
    (asserts! (< token-id (var-get next-token-id)) err-invalid-token-id) ;; Check if token-id is valid
    (asserts! (is-eq tx-sender (get seller listing)) err-not-token-owner)
    (map-delete listings { token-id: token-id })
    (ok true)
  )
)

;; Buy NFT
(define-public (buy-nft (token-id uint))
  (let
    (
      (listing (unwrap! (map-get? listings { token-id: token-id }) err-listing-not-found))
      (price (get price listing))
      (seller (get seller listing))
      (token (unwrap! (map-get? tokens { token-id: token-id }) err-invalid-token-id))
      (creator (get creator token))
      (royalty (get royalty token))
      (royalty-amount (/ (* price royalty) u10000))
      (seller-amount (- price royalty-amount))
    )
    (asserts! (< token-id (var-get next-token-id)) err-invalid-token-id) ;; Check if token-id is valid
    ;; Transfer royalty to creator
    (try! (stx-transfer? royalty-amount tx-sender creator))
    ;; Transfer remaining amount to seller
    (try! (stx-transfer? seller-amount tx-sender seller))
    ;; Transfer NFT ownership
    (try! (nft-transfer? pixelvault token-id seller tx-sender))
    ;; Update token ownership
    (map-set tokens
      { token-id: token-id }
      (merge token { owner: tx-sender })
    )
    ;; Remove listing
    (map-delete listings { token-id: token-id })
    (ok true)
  )
)

;; Get token details
(define-read-only (get-token-details (token-id uint))
  (ok (unwrap! (map-get? tokens { token-id: token-id }) err-invalid-token-id))
)

;; Get listing details
(define-read-only (get-listing (token-id uint))
  (ok (unwrap! (map-get? listings { token-id: token-id }) err-listing-not-found))
)