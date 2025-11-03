import { useState } from "react";

const TESTIMONIALS = [
  {
    avatar:
      "https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?auto=format&fit=crop&w=400&q=80",
    name: "John Samson",
    location: "ENUGU, NIGERIA",
    quote:
      "White dwarf a still more glorious dawn awaits tingling of the spine emerged into consciousness Vangelis shores of the cosmic ocean. Tendrils of gossamer clouds kindle hidden energy in matter.",
  },
  {
    avatar:
      "https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?auto=format&fit=crop&w=400&q=80",
    name: "Jane Obi",
    location: "ABUJA, NIGERIA",
    quote:
      "Food always arrives hot, portions are generous, and delivery is fast. The jollof is a 10/10 every time.",
  },
  {
    avatar:
      "https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?auto=format&fit=crop&w=400&q=80",
    name: "Ade A.",
    location: "LAGOS, NIGERIA",
    quote:
      "Clean, tasty, and reliable. Meal plans saved my weekday lunches. Highly recommended.",
  },
];

export default function Testimonials() {
  const [idx, setIdx] = useState(0);
  const t = TESTIMONIALS[idx];

  return (
    <section className="bg-rose-50">
      <div className="mx-auto max-w-7xl px-6 md:px-10 py-16 md:py-24 grid md:grid-cols-[1fr,1.4fr] items-start gap-10">
        {/* Left copy */}
        <div>
          <h2 className="text-4xl md:text-5xl font-extrabold text-gray-900 leading-tight">
            What our customers say
            <br /> about us
          </h2>
          <p className="mt-4 max-w-sm text-gray-600">
            At vero eos et accusamus et iusto odio dignissimos ducimus qui
            blanditiis praesentium voluptatum.
          </p>
        </div>

        {/* Testimonial card */}
        <div className="relative">
          <div className="rounded-2xl bg-white p-6 md:p-8 shadow-lg ring-1 ring-black/5">
            {/* quote mark */}
            <div className="absolute right-6 top-6 text-red-600 text-2xl font-black select-none">
              ”
            </div>

            <div className="grid gap-6 md:grid-cols-[200px,1fr] items-start">
              {/* person */}
              <div className="flex md:block items-center gap-4">
                <img
                  src={t.avatar}
                  alt={t.name}
                  className="h-24 w-24 rounded-full object-cover ring-2 ring-white shadow"
                />
                <div className="md:mt-4">
                  <p className="font-semibold text-gray-900">{t.name}</p>
                  <p className="text-xs font-semibold tracking-wide text-gray-500 mt-1">
                    {t.location}
                  </p>
                </div>
              </div>

              {/* quote */}
              <p className="text-gray-700 leading-relaxed">{t.quote}</p>
            </div>
          </div>

          {/* dots */}
          <div className="mt-6 flex justify-center gap-2">
            {TESTIMONIALS.map((_, i) => (
              <button
                key={i}
                aria-label={`Go to testimonial ${i + 1}`}
                onClick={() => setIdx(i)}
                className={
                  i === idx
                    ? "h-2.5 w-2.5 rounded-full bg-red-600"
                    : "h-2.5 w-2.5 rounded-full bg-gray-300 hover:bg-gray-400"
                }
              />
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
