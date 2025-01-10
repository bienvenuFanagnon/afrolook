import 'package:flutter/material.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';

class ListItemSlider extends StatelessWidget {
  final List<Widget> sliders;
  const ListItemSlider({Key? key, required this.sliders,}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return  Center(
        child: Builder(
          builder: (context) {
            final height = MediaQuery.of(context).size.height;
            return FlutterCarousel(
              options: FlutterCarouselOptions(
                height: 300,
                viewportFraction: 1.0,
                enlargeCenterPage: false,
                autoPlay: false,
                enableInfiniteScroll: true,
                autoPlayInterval: const Duration(seconds: 4),
                slideIndicator: CircularWaveSlideIndicator(),
                floatingIndicator: true,
                showIndicator: true
              ),
              items: sliders,
            );
          },
        ),
      );

  }
}
