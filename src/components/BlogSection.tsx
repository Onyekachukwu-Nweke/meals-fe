// import React from "react";

const POSTS = [
  {
    id: 1,
    category: "Design",
    date: "01 October 2019",
    title: "Better Than Takeout Kung Pao Chicken",
    excerpt:
      "This spicy, tangy, and sweet better-than-takeout no-peanut kung pao chicken stir fry recipe.",
    image:
      "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=800&q=80",
  },
  {
    id: 2,
    category: "Design",
    date: "01 October 2019",
    title: "The Best Sesame Soy Broccoli Salad",
    excerpt:
      "Hello broccoli salad! Broccoli salad with a sweet and tangy dressing is my new go-to for summer parties.",
    image:
      "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=800&q=80",
  },
  {
    id: 3,
    category: "Design",
    date: "01 October 2019",
    title: "Better Than Takeout Kung Pao Chicken",
    excerpt:
      "This super easy version of dan dan noodles is fast, flavorful, and vegetarian to boot. It’s definitely a keeper.",
    image:
      "https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?auto=format&fit=crop&w=800&q=80",
  },
];

export default function BlogSection() {
  return (
    <section className="bg-white">
      <div className="mx-auto max-w-7xl px-6 md:px-10 py-16 md:py-24">
        <h2 className="text-center text-3xl md:text-4xl font-extrabold text-gray-900">
          Blog Our Latest News
        </h2>
        <p className="mt-3 text-center text-gray-600 max-w-2xl mx-auto">
          Have you ever browsed food blogs like mine and wondered how to start a food blog of your very own?
        </p>

        <div className="mt-10 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {POSTS.map((post) => (
            <article
              key={post.id}
              className="rounded-xl bg-white shadow-sm ring-1 ring-black/5 transition hover:shadow-md"
            >
              <div className="px-6 pt-6">
                {/* circular image look */}
                <div className="mx-auto flex h-44 w-44 items-center justify-center overflow-hidden rounded-full shadow">
                  <img
                    src={post.image}
                    alt={post.title}
                    className="h-full w-full object-cover"
                    loading="lazy"
                  />
                </div>
              </div>

              <div className="p-6">
                <p className="text-xs font-semibold text-red-600">
                  {post.category} <span className="text-gray-400 mx-1">•</span> {post.date}
                </p>

                <h3 className="mt-2 font-semibold text-gray-900">{post.title}</h3>
                <p className="mt-2 text-sm text-gray-600">{post.excerpt}</p>

                <a
                  href="#"
                  className="mt-4 inline-block text-sm font-semibold text-red-600 hover:text-red-700"
                >
                  READ MORE
                </a>
              </div>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}
