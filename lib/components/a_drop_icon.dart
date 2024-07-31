import 'package:flutter/material.dart';

class ADropIcon extends StatelessWidget {
  const ADropIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest.shortestSide;
      return Stack(
        children: [
          _backCircle(
            size: size * 0.8,
          ),
          _wordA(
            size: size * 0.6,
          ),
        ],
      );
    });
  }

  Widget _backCircle({required double size}) {
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _wordA({required double size}) {
    return Center(
      child: Text(
        'A',
        style: TextStyle(
          fontSize: size,
          color: Colors.white,
        ),
      ),
    );
  }
}
