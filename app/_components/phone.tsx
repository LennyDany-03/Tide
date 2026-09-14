import Image from "next/image";

type Props = {
  screen: "today" | "history" | "insights";
  alt: string;
  priority?: boolean;
  className?: string;
  sizes?: string;
  style?: React.CSSProperties;
};

/**
 * A real screen from the app in a plain device frame.
 *
 * The screenshots are rendered from the Flutter app itself by
 * product/tool/site_screenshots_test.dart, so they never show a screen the
 * app does not have. Re-run that after a visible app change.
 */
export function Phone({ screen, alt, priority, className = "", sizes, style }: Props) {
  return (
    <div
      className={`aspect-[390/844] rounded-[44px] bg-[#0b1015] p-[7px] shadow-[0_40px_80px_-30px_var(--shadow),inset_0_0_0_1px_rgb(255_255_255/0.08)] ${className}`}
      style={style}
    >
      <Image
        src={`/screens/${screen}.png`}
        alt={alt}
        width={1170}
        height={2532}
        priority={priority}
        sizes={sizes ?? "(min-width: 1024px) 320px, 70vw"}
        className="h-full w-full rounded-[37px] object-cover"
      />
    </div>
  );
}
