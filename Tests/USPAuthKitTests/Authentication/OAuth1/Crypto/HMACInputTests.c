/* Standalone security regression. Synthetic vectors independently derived using Python hmac/hashlib. */
#include "hmac.h"
#include "sha1.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <pthread.h>

static void hex_digest(const unsigned char *digest, char *hex) {
  for (unsigned i = 0; i < 20; ++i) snprintf(hex + i * 2, 3, "%02x", digest[i]);
}
static void check_case(size_t message_length, size_t key_length, const char *expected) {
  unsigned char message[160], key[80], before_message[160], before_key[80], digest[20];
  for (unsigned i = 0; i < sizeof message; ++i) message[i] = (unsigned char)i;
  for (unsigned i = 0; i < sizeof key; ++i) key[i] = (unsigned char)i;
  memcpy(before_message, message, sizeof message); memcpy(before_key, key, sizeof key);
  hmac_sha1(message, message_length, key, key_length, digest);
  char hex[41] = {0}; hex_digest(digest, hex);
  assert(strcmp(hex, expected) == 0);
  assert(memcmp(message, before_message, sizeof message) == 0);
  assert(memcmp(key, before_key, sizeof key) == 0);
}
static void *check_vectors(void *unused) {
  (void)unused;
  check_case(3, 3, "d323ce40dda04b8206af88116562a9d3109a5853");
  check_case(160, 3, "291c7c902eeb026696c2592e0c76cc49d82df74e");
  check_case(3, 80, "e801dea93092d852fd4bbdb9fc6edceb7d32c0ce");
  check_case(160, 80, "29a0e954f29e8e0afaf85cdf1e1093cdb376f7f3");
  unsigned char digest[20]; char hex[41] = {0};
  hmac_sha1((const unsigned char *)"The quick brown fox jumps over the lazy dog", 43, (const unsigned char *)"key", 3, digest);
  hex_digest(digest, hex); assert(strcmp(hex, "de7c9b85b8b78aa6bc8a7a36f70a90701c9db4d9") == 0);
  /* Read-only + deliberately unaligned input exercises local SHA scratch storage. */
  static const unsigned char text[] = "xabcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq";
  SHA1_CTX context; SHA1Init(&context); SHA1Update(&context, text + 1, 56); SHA1Final(digest, &context);
  hex_digest(digest, hex); assert(strcmp(hex, "84983e441c3bd26ebaae4aa1f95129e5e54670f1") == 0);
  return NULL;
}
int main(void) {
  check_vectors(NULL);
  pthread_t threads[4];
  for (unsigned i = 0; i < 4; ++i) assert(pthread_create(&threads[i], NULL, check_vectors, NULL) == 0);
  for (unsigned i = 0; i < 4; ++i) assert(pthread_join(threads[i], NULL) == 0);
  puts("HMAC/SHA1: 4 audit cases + 2 known vectors; input integrity and 4-thread isolation passed");
  return 0;
}
