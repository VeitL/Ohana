export { CatAvatar } from './CatAvatar';
export { DogAvatar } from './DogAvatar';
export { RabbitAvatar } from './RabbitAvatar';
export { HamsterAvatar } from './HamsterAvatar';
export { BirdAvatar } from './BirdAvatar';

export interface AvatarProps {
  furColor?: string;
  patternColor?: string;
  eyeColor?: string;
  className?: string;
}

import React from 'react';
import { CatAvatar } from './CatAvatar';
import { DogAvatar } from './DogAvatar';
import { RabbitAvatar } from './RabbitAvatar';
import { HamsterAvatar } from './HamsterAvatar';
import { BirdAvatar } from './BirdAvatar';

const AVATAR_MAP: Record<string, React.FC<AvatarProps>> = {
  cat: CatAvatar,
  dog: DogAvatar,
  rabbit: RabbitAvatar,
  hamster: HamsterAvatar,
  bird: BirdAvatar,
};

/** Usage: <PetAvatar species="cat" furColor="#FF7A00" eyeColor="#4A90E2" /> */
export function PetAvatar({ species, ...props }: AvatarProps & { species: string }) {
  const Component = AVATAR_MAP[species.toLowerCase()] ?? CatAvatar;
  return <Component {...props} />;
}
