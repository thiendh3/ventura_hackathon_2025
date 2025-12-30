import 'package:flutter/material.dart';

import 'login_page.dart';

class ShoppingList extends StatefulWidget {
  const ShoppingList({super.key});

  @override
 // ignore: library_private_types_in_public_api
 _ShoppingListState createState() => _ShoppingListState();
}

class _ShoppingListState extends State<ShoppingList> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _shoppingList = [];
  final Set<String> _checkedItems = {};

  void _addItem() {
    final item = _controller.text.trim();
    if (item.isNotEmpty) {
      setState(() {
        _shoppingList.add(item);
      });
      _controller.clear();
    }
  }

  void _clearCheckedItems() {
    setState(() {
      _shoppingList.removeWhere((item) => _checkedItems.contains(item));
      _checkedItems.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.person),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => LoginPage()),
            );
          },
        ),
        title: const Text('Shopping List'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Add an item',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                ElevatedButton(
                  onPressed: _addItem,
                  child: const Text('+'),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            Expanded(
              child: ListView.builder(
                itemCount: _shoppingList.length,
                itemBuilder: (context, index) {
                  final item = _shoppingList[index];
                  return ListTile(
                    leading: Checkbox(
                      value: _checkedItems.contains(item),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _checkedItems.add(item);
                          } else {
                            _checkedItems.remove(item);
                          }
                        });
                      },
                    ),
                    title: Text(item),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          _shoppingList.remove(item);
                          _checkedItems.remove(item);
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
