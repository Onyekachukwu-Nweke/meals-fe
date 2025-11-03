import { useMemo, useState } from "react";

import imgJollof from "@/assets/jollof-chicken.jpg";
import imgDrawSoup from "@/assets/draw-soup.jpg";
import imgFriesEgg from "@/assets/fries-egg.png";
import imgEgusi from "@/assets/egusi.jpg";
import imgBeans from "@/assets/beans.jpg";
import imgFriedRice from "@/assets/fried-rice.jpg";

type MenuItem = {
  id: string;
  name: string;
  desc: string;
  price: number; // naira
  category: "Rice" | "Beans" | "Fries" | "Swallow" | "Others";
  image: string;
};

const ITEMS: MenuItem[] = [
  {
    id: "jollof",
    name: "Jollof Rice and Chicken",
    desc: "Fried potato/yam chips with egg sauce or any topping of your choice",
    price: 1500,
    category: "Rice",
    image: imgJollof,
  },
  {
    id: "draw",
    name: "Swallow with Draw Soup",
    desc: "Fried potato/yam chips with egg sauce or any topping of your choice",
    price: 1000,
    category: "Swallow",
    image: imgDrawSoup,
  },
  {
    id: "fries-egg",
    name: "Fries with Egg sauce",
    desc: "Fried potato/yam chips with egg sauce or any topping of your choice",
    price: 1500,
    category: "Fries",
    image: imgFriesEgg,
  },
  {
    id: "egusi",
    name: "Swallow with Egusi Soup",
    desc: "Nicely cooked egusi soup and eba",
    price: 1000,
    category: "Swallow",
    image: imgEgusi,
  },
  {
    id: "beans",
    name: "Beans",
    desc: "Fried potato/yam chips with egg sauce or any topping",
    price: 700,
    category: "Beans",
    image: imgBeans,
  },
  {
    id: "fried-rice",
    name: "Fried Rice",
    desc: "Fried rice with chicken or any topping of your choice",
    price: 600,
    category: "Rice",
    image: imgFriedRice,
  },
];

const TABS = ["All", "Rice", "Beans", "Fries", "Swallow", "Others"] as const;
type Tab = (typeof TABS)[number];

const MenuSection = () => {
  const [active, setActive] = useState<Tab>("All");

  const filtered = useMemo(() => {
    if (active === "All") return ITEMS;
    return ITEMS.filter((i) => i.category === active);
  }, [active]);

  return (
    <section id="menu" className="bg-neutral-50/70">
      <div className="mx-auto max-w-7xl px-6 md:px-10 py-12 md:py-16">
        {/* Eyebrow */}
        <p className="text-xs font-semibold tracking-wide text-red-600 mb-1">
          MENU
        </p>
        <h2 className="text-3xl md:text-4xl font-bold text-gray-900">
          Current menu
        </h2>

        {/* Tabs */}
        <div
          className="mt-6 flex flex-wrap items-center gap-2 border rounded-lg p-1 bg-white"
          role="tablist"
          aria-label="Filter menu by category"
        >
          {TABS.map((tab) => {
            const isActive = tab === active;
            return (
              <button
                key={tab}
                role="tab"
                aria-selected={isActive}
                onClick={() => setActive(tab)}
                className={`px-3 py-1 text-sm font-medium transition ${
                  isActive
                    ? "bg-red-600 text-white rounded-md"
                    : "text-gray-700 hover:text-red-600"
                }`}
              >
                {tab}
              </button>
            );
          })}
        </div>

        {/* Grid */}
        <div className="mt-8 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {filtered.map((item) => (
            <article
              key={item.id}
              className="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-black/5 transition hover:shadow-md"
            >
              <div className="aspect-[4/3] w-full overflow-hidden">
                <img
                  src={item.image}
                  alt={item.name}
                  className="h-full w-full object-cover"
                  loading="lazy"
                />
              </div>

              <div className="p-4">
                <h3 className="font-semibold text-gray-900">{item.name}</h3>
                <p className="mt-1 text-sm text-gray-500">{item.desc}</p>

                <div className="mt-3 border-t pt-3">
                  <span className="text-gray-900 font-semibold">
                    ₦ {item.price.toLocaleString("en-NG")}
                  </span>
                </div>
              </div>
            </article>
          ))}
        </div>

        {/* Empty state (e.g., Others) */}
        {filtered.length === 0 && (
          <div className="mt-10 rounded-lg border bg-white p-6 text-center text-gray-600">
            No items in <span className="font-semibold">{active}</span> yet.
          </div>
        )}

         {/* Full Menu Button */}
         <div className="mt-12 flex justify-center">
          <button
            onClick={() => {}}
            className="bg-red-600 text-white font-semibold py-3 px-8 rounded-full hover:bg-red-700 transition-all"
          >
            Full Menu
          </button>
        </div>
      </div>
    </section>
  );
};

export default MenuSection;
