import Logo from '@/assets/logo.svg'

export default function Navigation() {
  return (
    <nav className="flex items-center justify-between px-8 py-4 bg-white shadow-sm">
      <div className="flex items-center gap-2">
        <img src={Logo} alt="Meals Logo" className="h-8 w-auto" />
      </div>

      <ul className="flex gap-8 text-gray-700">
        <li className="hover:text-red-600 cursor-pointer">Home</li>
        <li className="hover:text-red-600 cursor-pointer">Menu</li>
        <li className="hover:text-red-600 cursor-pointer">Meal Plans</li>
      </ul>

      <div className="flex gap-3">
        <button className="text-gray-700 font-medium">Sign In</button>
        <button className="bg-red-600 text-white font-semibold px-5 py-2 rounded-full hover:bg-red-700">
          Create Account
        </button>
      </div>
    </nav>
  );
}