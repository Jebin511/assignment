//implementing a custo new data type 
class Experience {
  // the variables are the properties of this particular data type which we use to store the info from the API response 
  final int id;
  final String name;
  final String tagline;
  final String description;
  final String imageUrl;
  final String iconUrl;

  Experience({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.imageUrl,
    required this.iconUrl,
  });

  factory Experience.fromJson(Map<String, dynamic> json) {//this is used for creating an object from a json Map
    return Experience(
      //the lines from 23 to 28 converts the response from API to usable objects,
      //also using default values cause it would stop the app crash if any error occur
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      tagline: json['tagline'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'] ?? '',
      iconUrl: json['icon_url'] ?? '',
    );
  }
//since the API returns a list of experiences we use the below lines it converts the JSON object to Flutter objects list
  static List<Experience> listFromJson(List<dynamic> list) {
    return list.map((e) => Experience.fromJson(e)).toList();
  }
}