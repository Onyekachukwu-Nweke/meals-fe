import { FaFacebookF, FaInstagram, FaTwitter } from "react-icons/fa";
import Logo from "@/assets/logo.svg";

const Footer = () => {
  return (
    <footer className="bg-neutral-50/70">
      <div className="mx-auto max-w-7xl px-6 md:px-10 py-12 grid md:grid-cols-3 gap-10 items-start">
        {/* Left: Logo and copyright */}
        <div>
          <div className="flex items-center space-x-2">
            <img src={Logo} alt="Meals logo" className="h-8 w-auto" />
            <span className="text-xl font-bold text-gray-900">Meals</span>
          </div>
          <p className="mt-6 text-sm text-gray-500">
            © 2022 Meals. All rights reserved.
          </p>
        </div>

        {/* Middle: Links */}
        <div className="grid grid-cols-2 gap-10 text-sm">
          <div>
            <h4 className="font-semibold text-gray-900 mb-3">Company</h4>
            <ul className="space-y-2 text-gray-600">
              <li>
                <a href="#" className="hover:text-red-600">Blog</a>
              </li>
              <li>
                <a href="#" className="hover:text-red-600">About us</a>
              </li>
              <li>
                <a href="#" className="hover:text-red-600">Contact us</a>
              </li>
            </ul>
          </div>
          <div>
            <h4 className="font-semibold text-gray-900 mb-3">Services</h4>
            <ul className="space-y-2 text-gray-600">
              <li>
                <a href="#" className="hover:text-red-600">FAQs</a>
              </li>
              <li>
                <a href="#" className="hover:text-red-600">Our Menu</a>
              </li>
            </ul>
          </div>
        </div>

        {/* Right: Social icons */}
        <div className="flex md:justify-end gap-4 mt-6 md:mt-0">
          <a
            href="#"
            className="h-10 w-10 flex items-center justify-center rounded-full bg-yellow-50 text-gray-700 hover:bg-yellow-100"
          >
            <FaFacebookF />
          </a>
          <a
            href="#"
            className="h-10 w-10 flex items-center justify-center rounded-full bg-gray-100 text-gray-700 hover:bg-gray-200"
          >
            <FaInstagram />
          </a>
          <a
            href="#"
            className="h-10 w-10 flex items-center justify-center rounded-full bg-yellow-50 text-gray-700 hover:bg-yellow-100"
          >
            <FaTwitter />
          </a>
        </div>
      </div>
    </footer>
  );
};

export default Footer;
