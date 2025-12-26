// ignore_for_file: avoid_print
void main() {
  print("Probing Jyotish package...");
  try {
    // Attempt standard calls or check reflection if possible (Dart doesn't support easy reflection like this without mirrors)
    // Just simple instantiation to see if it links.
    // var j = Jyotish(); // Guess
    print("Import successful.");
  } catch (e) {
    print("Error: $e");
  }
}
