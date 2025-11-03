import heroImage from "@/assets/hero_plate.png";
const Hero = () => {
  return (
    <section className="flex flex-col md:flex-row items-center justify-between px-10 md:px-20 py-16 bg-white">
      <div className="max-w-lg">
        <h1 className="text-4xl md:text-5xl font-extrabold text-gray-900 leading-tight">
          Delicious meals at your convenience
        </h1>
        <p className="mt-4 text-gray-600 text-lg">
          Order your meals from us and we will have it delivered at your doorstep.
        </p>
        <button className="mt-8 bg-red-600 text-white font-semibold py-3 px-8 rounded-full hover:bg-red-700 transition-all">
          Get Started
        </button>
      </div>

      <div className="relative mt-10 md:mt-0">
        <img
          src={heroImage}
          alt="Jollof rice with chicken"
          className="relative w-auto object-cover"
        />
      </div>
    </section>
  );
};

export default Hero;
