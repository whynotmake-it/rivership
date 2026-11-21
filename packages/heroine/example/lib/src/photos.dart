/// Photos from Lorem Picsum (picsum.photos), which serves free photos from
/// Unsplash. Each entry keeps the photo's real photographer and size, as
/// listed by `https://picsum.photos/v2/list`.
library;

/// A photo on picsum.photos.
class Photo {
  const Photo(this.id, this.author, this.width, this.height);

  /// The photo's id on picsum.photos.
  final int id;

  /// The photographer.
  final String author;

  /// The original width in pixels.
  final int width;

  /// The original height in pixels.
  final int height;

  /// Width over height.
  double get aspectRatio => width / height;

  /// The photo, cropped to a square [size] pixels wide.
  String square(int size) => 'https://picsum.photos/id/$id/$size/$size';

  /// The whole photo, [longEdge] pixels on its longer side.
  String fit(int longEdge) {
    final w = width >= height ? longEdge : (longEdge * aspectRatio).round();
    final h = width >= height ? (longEdge / aspectRatio).round() : longEdge;
    return 'https://picsum.photos/id/$id/$w/$h';
  }

  /// Every photo by the same photographer in [photos].
  List<Photo> get byAuthor => [
        for (final photo in photos)
          if (photo.author == author) photo,
      ];
}

/// The photos the demos show.
const photos = [
  Photo(84, 'Johnny Lam', 1280, 848),
  Photo(142, 'Vadim Sherbakov', 4272, 2848),
  Photo(58, 'Tony Naccarato', 1280, 853),
  Photo(122, 'Vadim Sherbakov', 4147, 2756),
  Photo(46, 'Jeffrey Kam', 3264, 2448),
  Photo(202, 'Glen Carrie', 2392, 1260),
  Photo(49, 'Margaret Barley', 1280, 792),
  Photo(64, 'Alexander Shustov', 4326, 2884),
  Photo(106, 'Arvee Marie', 2592, 1728),
  Photo(110, 'Kenneth Thewissen', 5000, 3333),
  Photo(177, 'Danka & Peter', 2515, 1830),
  Photo(164, 'Linh Nguyen', 1200, 800),
  Photo(116, 'Anton Sulsky', 3504, 2336),
  Photo(37, 'Austin Neill', 2000, 1333),
  Photo(10, 'Paul Jarvis', 2500, 1667),
  Photo(195, 'Matthew Skinner', 768, 1024),
  Photo(74, 'Isaak Dury', 4288, 2848),
  Photo(54, 'Nicholas Swanson', 3264, 2176),
  Photo(76, 'Alexander Shustov', 4912, 3264),
  Photo(183, 'müllermarc', 2316, 1544),
  Photo(197, 'Kholodnitskiy Maksim', 4272, 2848),
  Photo(77, 'May Pamintuan', 1631, 1102),
  Photo(204, 'Tiago Gerken', 5000, 3333),
  Photo(29, 'Go Wild', 4000, 2670),
  Photo(165, 'Linh Nguyen', 2000, 1333),
  Photo(69, 'Alexander Shustov', 4912, 3264),
  Photo(129, 'Charlie Foster', 4910, 3252),
  Photo(11, 'Paul Jarvis', 2500, 1667),
  Photo(174, 'Linh Nguyen', 1600, 589),
  Photo(65, 'Alexander Shustov', 4912, 3264),
  Photo(152, 'Steven Spassov', 3888, 2592),
  Photo(62, 'Daniel Genser', 2000, 1333),
  Photo(191, 'Alex Talmon', 2560, 1707),
  Photo(101, 'Christian Bardenhorst', 2621, 1747),
  Photo(103, 'Ilham Rahmansyah', 2592, 1936),
  Photo(17, 'Paul Jarvis', 2500, 1667),
  Photo(13, 'Paul Jarvis', 2500, 1667),
  Photo(57, 'Nicholas Swanson', 2448, 3264),
  Photo(128, 'Matteo Minelli', 3823, 2549),
  Photo(193, 'Vadim Sherbakov', 3578, 2451),
  Photo(155, 'Christopher Sardegna', 3264, 2176),
  Photo(82, 'Rula Sibai', 1500, 997),
  Photo(28, 'Jerry Adney', 4928, 3264),
  Photo(133, 'Dietmar Becker', 2742, 1828),
  Photo(16, 'Paul Jarvis', 2500, 1667),
  Photo(15, 'Paul Jarvis', 2500, 1667),
  Photo(176, 'Good Free Photos', 2500, 1662),
  Photo(85, 'Gozha Net', 1280, 774),
  Photo(42, 'Luke Chesser', 3456, 2304),
  Photo(75, 'Jassy Onyae', 1999, 2998),
];
