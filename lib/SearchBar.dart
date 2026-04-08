import 'package:flutter/material.dart';

class SearChBar extends StatefulWidget {
  final ValueChanged<String>? onQueryChanged;

  const SearChBar({super.key, this.onQueryChanged});

  @override
  State<SearChBar> createState() => _SearChBarState();
}

class _SearChBarState extends State<SearChBar> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: _searchController,
        onChanged: (value) {
          if (widget.onQueryChanged != null) {
            widget.onQueryChanged!(value.trim());
          }
          setState(() {});
        },
        cursorColor: const Color.fromRGBO(107, 59, 225, 1),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: "Search inventory...",
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 15,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Colors.grey,
            size: 22,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    if (widget.onQueryChanged != null) {
                      widget.onQueryChanged!('');
                    }
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color.fromRGBO(107, 59, 225, 0.4),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
